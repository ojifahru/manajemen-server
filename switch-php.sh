#!/bin/bash

# Fungsi untuk logging
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "/var/log/website-management.log"
}

# Fungsi validasi domain
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Format domain tidak valid: $domain"
        return 1
    fi
    return 0
}

# Fungsi validasi versi PHP
validate_php_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Format versi PHP tidak valid: $version"
        echo "   Contoh yang benar: 7.4, 8.1, 8.3"
        return 1
    fi
    
    # Cek apakah service PHP-FPM tersedia
    if ! systemctl list-units --type=service | grep -q "php$version-fpm.service"; then
        echo "❌ Service php$version-fpm tidak ditemukan!"
        echo "   Install dengan: apt install php$version-fpm"
        return 1
    fi
    
    return 0
}

# Fungsi untuk auto-detect PHP version saat ini
auto_detect_current_php() {
    local domain=$1
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    
    if [ ! -f "$vhost_file" ]; then
        echo ""
        return 1
    fi
    
    # Cari versi PHP dari vhost file
    local php_version=$(grep -oP 'php\K\d+\.\d+(?=-fmp)' "$vhost_file" | head -n1)
    
    if [ -n "$php_version" ]; then
        echo "$php_version"
        return 0
    else
        echo ""
        return 1
    fi
}

# Fungsi untuk menampilkan informasi website
show_website_info() {
    local domain=$1
    local username=$2
    local current_php=$3
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    local user_home="/home/$username"
    
    echo ""
    echo "📋 INFORMASI WEBSITE:"
    echo "===================="
    echo "🌐 Domain        : $domain"
    echo "👤 Username      : $username"
    echo "🛠️  PHP Saat Ini  : $current_php"
    echo "📁 Home Directory: $user_home"
    echo "📄 VHost File    : $vhost_file"
    
    # Cek status website
    if [ -L "/etc/apache2/sites-enabled/$domain.conf" ]; then
        echo "🟢 Website Status: AKTIF"
    else
        echo "🔴 Website Status: NONAKTIF"
    fi
    
    # Cek pool status
    local current_pool="/etc/php/$current_php/fpm/pool.d/$username.conf"
    if [ -f "$current_pool" ]; then
        echo "🟢 Pool Status   : AKTIF"
    else
        echo "🔴 Pool Status   : NONAKTIF"
    fi
    
    # Cek socket
    local current_socket="/run/php/php$current_php-fpm-$username.sock"
    if [ -S "$current_socket" ]; then
        echo "🟢 Socket Status : AKTIF"
    else
        echo "🔴 Socket Status : NONAKTIF"
    fi
    
    # Cek ukuran website
    if [ -d "$user_home" ]; then
        local size=$(du -sh "$user_home" 2>/dev/null | cut -f1)
        echo "📊 Ukuran Website: $size"
    fi
    
    echo ""
}

# Fungsi untuk check compatibility
check_php_compatibility() {
    local old_ver=$1
    local new_ver=$2
    
    echo "🔍 Memeriksa compatibility PHP $old_ver → $new_ver..."
    
    # Version comparison
    local old_major=$(echo "$old_ver" | cut -d. -f1)
    local old_minor=$(echo "$old_ver" | cut -d. -f2)
    local new_major=$(echo "$new_ver" | cut -d. -f1)
    local new_minor=$(echo "$new_ver" | cut -d. -f2)
    
    # Warning untuk major version changes
    if [ "$old_major" != "$new_major" ]; then
        echo "⚠️  PERINGATAN: Major version change ($old_major.x → $new_major.x)"
        echo "   • Kemungkinan ada breaking changes"
        echo "   • Testing diperlukan setelah switch"
        echo "   • Backup database sebelum switch sangat disarankan"
        return 1
    fi
    
    # Info untuk minor version changes
    if [ "$old_minor" != "$new_minor" ]; then
        echo "ℹ️  Info: Minor version change ($old_ver → $new_ver)"
        echo "   • Biasanya backward compatible"
        echo "   • Testing tetap disarankan"
    fi
    
    return 0
}

# === INPUT dengan validasi ===
while true; do
    read -p "Masukkan nama domain (contoh: mysite.local): " DOMAIN
    if validate_domain "$DOMAIN"; then
        break
    fi
done

# Cek apakah website ada
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
if [ ! -f "$VHOST_FILE" ]; then
    echo "❌ Website dengan domain $DOMAIN tidak ditemukan!"
    echo "   File vhost tidak ada: $VHOST_FILE"
    exit 1
fi

USERNAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')

# Auto-detect current PHP version
echo "🔍 Mendeteksi versi PHP saat ini..."
CURRENT_PHP=$(auto_detect_current_php "$DOMAIN")

if [ -n "$CURRENT_PHP" ]; then
    echo "✅ Terdeteksi PHP version saat ini: $CURRENT_PHP"
    read -p "Gunakan $CURRENT_PHP sebagai versi lama? (Y/n): " USE_CURRENT
    if [[ "$USE_CURRENT" =~ ^[Nn]$ ]]; then
        while true; do
            read -p "Masukkan versi PHP lama (contoh: 7.4): " OLDVER
            if validate_php_version "$OLDVER"; then
                break
            fi
        done
    else
        OLDVER="$CURRENT_PHP"
    fi
else
    echo "⚠️ Tidak dapat mendeteksi versi PHP otomatis"
    while true; do
        read -p "Masukkan versi PHP lama (contoh: 7.4): " OLDVER
        if validate_php_version "$OLDVER"; then
            break
        fi
    done
fi

while true; do
    read -p "Masukkan versi PHP baru (contoh: 8.1): " NEWVER
    if validate_php_version "$NEWVER"; then
        break
    fi
done

# Cek apakah versi sama
if [ "$OLDVER" = "$NEWVER" ]; then
    echo "❌ Versi PHP lama dan baru sama ($OLDVER). Tidak ada yang perlu diubah."
    exit 1
fi

OLD_POOL="/etc/php/$OLDVER/fmp/pool.d/$USERNAME.conf"
NEW_POOL="/etc/php/$NEWVER/fpm/pool.d/$USERNAME.conf"
OLD_SOCK="/run/php/php$OLDVER-fpm-$USERNAME.sock"
NEW_SOCK="/run/php/php$NEWVER-fpm-$USERNAME.sock"
BACKUP_DIR="/root/php-switch-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_PREFIX="$BACKUP_DIR/${USERNAME}_${OLDVER}_to_${NEWVER}_$DATE"

# Buat direktori backup
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Tampilkan informasi website
show_website_info "$DOMAIN" "$USERNAME" "$OLDVER"

# Check compatibility
COMPATIBILITY_WARNING=false
if ! check_php_compatibility "$OLDVER" "$NEWVER"; then
    COMPATIBILITY_WARNING=true
fi

echo ""
echo "🔄 Akan switch PHP untuk domain: $DOMAIN"
echo "📊 Dari PHP $OLDVER ke PHP $NEWVER"
echo "👤 Username: $USERNAME"

if [ "$COMPATIBILITY_WARNING" = true ]; then
    echo ""
    echo "⚠️  PERHATIAN: Ada potential compatibility issues!"
    echo "   Pastikan website sudah dibackup sebelum melanjutkan."
fi

echo ""

# Konfirmasi sebelum eksekusi
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Operasi dibatalkan."
    exit 0
fi

log_action "Starting PHP switch for $DOMAIN from $OLDVER to $NEWVER"

# ✅ Validasi komprehensif
echo ""
echo "🔍 Melakukan validasi..."

if [ ! -f "$OLD_POOL" ]; then
    echo "❌ Pool config tidak ditemukan di versi lama: $OLD_POOL"
    log_action "ERROR: Old pool config not found: $OLD_POOL"
    exit 1
fi

if [ ! -f "$VHOST_FILE" ]; then
    echo "❌ File vhost tidak ditemukan: $VHOST_FILE"
    log_action "ERROR: Vhost file not found: $VHOST_FILE"
    exit 1
fi

# Cek apakah versi baru sudah ada (conflict detection)
if [ -f "$NEW_POOL" ]; then
    echo "⚠️ Pool config untuk PHP $NEWVER sudah ada"
    read -p "Timpa existing pool? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "❌ Operasi dibatalkan untuk menghindari konflik."
        exit 1
    fi
fi

# Cek service PHP-FMP untuk versi baru
if ! systemctl is-active php$NEWVER-fpm &>/dev/null; then
    echo "⚠️ Service php$NEWVER-fpm tidak aktif, mencoba start..."
    if systemctl start php$NEWVER-fpm 2>/dev/null; then
        echo "✅ Service php$NEWVER-fmp berhasil distart"
    else
        echo "❌ Gagal start service php$NEWVER-fpm"
        exit 1
    fi
fi

echo "✅ Validasi berhasil."

# � Backup konfigurasi sebelum perubahan
echo ""
echo "📦 Membuat backup konfigurasi..."

# Backup pool lama
if ! cp "$OLD_POOL" "$BACKUP_PREFIX.old_pool.backup"; then
    echo "❌ Gagal backup pool lama"
    log_action "ERROR: Failed to backup old pool"
    exit 1
fi

# Backup vhost
if ! cp "$VHOST_FILE" "$BACKUP_PREFIX.vhost.backup"; then
    echo "❌ Gagal backup vhost"
    log_action "ERROR: Failed to backup vhost"
    exit 1
fi

# Backup pool baru jika ada
if [ -f "$NEW_POOL" ]; then
    cp "$NEW_POOL" "$BACKUP_PREFIX.existing_new_pool.backup"
fi

echo "✅ Backup berhasil: $BACKUP_PREFIX.*"
log_action "Backup created: $BACKUP_PREFIX.*"

# 🔁 Membuat dan mengkonfigurasi pool baru
echo ""
echo "🔄 Mengkonfigurasi PHP-FPM pool baru..."

if ! cp "$OLD_POOL" "$NEW_POOL"; then
    echo "❌ Gagal menyalin pool config"
    log_action "ERROR: Failed to copy pool config"
    exit 1
fi

# Update socket path dalam pool config dengan lebih presisi
if ! sed -i "s|listen = /run/php/php$OLDVER-fpm-$USERNAME\.sock|listen = /run/php/php$NEWVER-fmp-$USERNAME.sock|g" "$NEW_POOL"; then
    echo "❌ Gagal update socket path dalam pool config"
    log_action "ERROR: Failed to update socket path in pool config"
    # Rollback
    rm -f "$NEW_POOL"
    exit 1
fi

# Test konfigurasi PHP-FPM
if ! php-fpm$NEWVER -t &>/dev/null; then
    echo "❌ Konfigurasi PHP-FPM tidak valid"
    log_action "ERROR: Invalid PHP-FMP configuration"
    # Rollback
    rm -f "$NEW_POOL"
    exit 1
fi

# Restart PHP-FPM versi baru
if ! systemctl restart php$NEWVER-fpm; then
    echo "❌ Gagal restart php$NEWVER-fpm"
    log_action "ERROR: Failed to restart php$NEWVER-fpm"
    # Rollback
    rm -f "$NEW_POOL"
    exit 1
fi

# Tunggu dan verifikasi socket
sleep 2
if [ ! -S "$NEW_SOCK" ]; then
    echo "❌ Socket PHP-FPM baru tidak aktif: $NEW_SOCK"
    log_action "ERROR: New PHP-FPM socket not active"
    # Rollback
    rm -f "$NEW_POOL"
    systemctl restart php$NEWVER-fpm
    exit 1
fi

echo "✅ PHP-FPM pool baru berhasil dikonfigurasi"
log_action "New PHP-FPM pool configured successfully"

# 📝 Update konfigurasi Apache vhost
echo ""
echo "📝 Memperbarui konfigurasi Apache vhost..."

# Backup vhost dengan timestamp
cp "$VHOST_FILE" "$VHOST_FILE.switch_backup.$DATE"

# Update socket path dalam vhost dengan presisi tinggi
if ! sed -i "s|proxy:unix:/run/php/php$OLDVER-fpm-$USERNAME\.sock|proxy:unix:/run/php/php$NEWVER-fmp-$USERNAME.sock|g" "$VHOST_FILE"; then
    echo "❌ Gagal mengubah vhost"
    log_action "ERROR: Failed to update vhost"
    # Rollback
    cp "$BACKUP_PREFIX.vhost.backup" "$VHOST_FILE"
    rm -f "$NEW_POOL"
    systemctl restart php$NEWVER-fpm
    exit 1
fi

# Test konfigurasi Apache
if ! apache2ctl configtest 2>/dev/null; then
    echo "❌ Konfigurasi Apache tidak valid"
    log_action "ERROR: Invalid Apache configuration"
    # Rollback
    cp "$BACKUP_PREFIX.vhost.backup" "$VHOST_FILE"
    rm -f "$NEW_POOL"
    systemctl restart php$NEWVER-fpm
    exit 1
fi

# Reload Apache
if ! systemctl reload apache2; then
    echo "❌ Gagal reload Apache"
    log_action "ERROR: Failed to reload Apache"
    # Rollback
    cp "$BACKUP_PREFIX.vhost.backup" "$VHOST_FILE"
    rm -f "$NEW_POOL"
    systemctl reload apache2
    systemctl restart php$NEWVER-fpm
    exit 1
fi

echo "✅ Apache vhost berhasil diperbarui"
log_action "Apache vhost updated successfully"

# � Test website dengan versi PHP baru
echo ""
echo "🧪 Testing website dengan PHP $NEWVER..."

# Test website accessibility
sleep 2  # Tunggu services fully restart

WEBSITE_TEST_PASSED=false
if curl -s -k "https://$DOMAIN" -o /dev/null 2>/dev/null; then
    echo "✅ Website dapat diakses via HTTPS"
    WEBSITE_TEST_PASSED=true
elif curl -s "http://$DOMAIN" -o /dev/null 2>/dev/null; then
    echo "✅ Website dapat diakses via HTTP"  
    WEBSITE_TEST_PASSED=true
else
    echo "⚠️ Website tidak dapat diakses dari localhost"
    echo "   Periksa konfigurasi DNS atau hosts file"
fi

# Test PHP functionality
if [ "$WEBSITE_TEST_PASSED" = true ]; then
    echo "✅ Website berfungsi dengan PHP $NEWVER"
    log_action "Website test passed with PHP $NEWVER"
else
    echo "⚠️ Website test gagal, tapi switch tetap dilanjutkan"
    log_action "WARNING: Website test failed but switch completed"
fi

# 🧹 Nonaktifkan versi PHP lama
echo ""
echo "🧹 Menonaktifkan versi PHP lama..."

if [ -f "$OLD_POOL" ]; then
    if mv "$OLD_POOL" "$OLD_POOL.disabled"; then
        echo "✅ Pool PHP lama dinonaktifkan: $OLD_POOL.disabled"
        log_action "Old PHP pool disabled: $OLD_POOL"
    else
        echo "⚠️ Gagal disable pool lama, tapi website tetap berfungsi"
        log_action "WARNING: Failed to disable old pool"
    fi
    
    # Restart service lama untuk membersihkan socket
    if systemctl restart php$OLDVER-fpm 2>/dev/null; then
        echo "✅ Service PHP $OLDVER direstart (cleanup)"
    else
        echo "⚠️ Gagal restart php$OLDVER-fpm (normal jika tidak ada pool aktif)"
    fi
else
    echo "⚠️ Pool lama sudah tidak ada: $OLD_POOL"
fi

# Verifikasi socket lama sudah hilang
if [ ! -S "$OLD_SOCK" ]; then
    echo "✅ Socket PHP lama berhasil dihapus"
else
    echo "⚠️ Socket PHP lama masih ada: $OLD_SOCK"
fi

log_action "PHP switch completed successfully for $DOMAIN from $OLDVER to $NEWVER"

echo ""
echo "🎉 Versi PHP untuk $DOMAIN berhasil diubah!"
echo "============================================"
echo "📊 Summary:"
echo "   🔄 PHP Switch   : $OLDVER → $NEWVER"
echo "   🌐 Domain       : $DOMAIN"  
echo "   👤 Username     : $USERNAME"
echo "   � Socket Baru  : $NEW_SOCK"
echo "   📄 Pool Baru    : $NEW_POOL"
echo "   🌐 VHost        : $VHOST_FILE"
echo ""

# Verifikasi final status
echo "🔍 Status Verification:"

# Cek Apache site status
if [ -L "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
    echo "   🌐 Apache Site  : ✅ ENABLED"
else
    echo "   🌐 Apache Site  : ❌ DISABLED"
fi

# Cek pool baru
if [ -f "$NEW_POOL" ]; then
    echo "   ⚙️  PHP Pool     : ✅ ACTIVE (PHP $NEWVER)"
else
    echo "   ⚙️  PHP Pool     : ❌ NOT FOUND"
fi

# Cek socket baru
if [ -S "$NEW_SOCK" ]; then
    echo "   🔌 PHP Socket   : ✅ ACTIVE"
else
    echo "   🔌 PHP Socket   : ❌ NOT ACTIVE"
fi

# Cek pool lama
if [ -f "$OLD_POOL.disabled" ]; then
    echo "   🗃️  Old Pool     : ✅ DISABLED"
elif [ -f "$OLD_POOL" ]; then
    echo "   🗃️  Old Pool     : ⚠️  STILL ACTIVE"
else
    echo "   🗃️  Old Pool     : ✅ REMOVED"
fi

echo ""
echo "📦 Backup Files:"
echo "   📁 Old Pool     : $BACKUP_PREFIX.old_pool.backup"
echo "   🌐 VHost        : $BACKUP_PREFIX.vhost.backup"
echo "   📄 Apache       : $VHOST_FILE.switch_backup.$DATE"
echo ""

echo "🌍 Test Website:"
echo "   HTTP  : http://$DOMAIN"
echo "   HTTPS : https://$DOMAIN"
echo ""

echo "📋 Management Commands:"
echo "   • Check status  : ./check-php-versions.sh -s"
echo "   • View logs     : tail -f /var/log/website-management.log"
echo "   • Test PHP      : curl -k https://$DOMAIN"
echo "   • Rollback      : Gunakan backup files jika diperlukan"
echo ""

echo "💡 Post-Switch Checklist:"
echo "   ✓ Test website functionality"
echo "   ✓ Check error logs: tail -f /var/log/apache2/$DOMAIN.error.log"
echo "   ✓ Verify PHP version: curl -s https://$DOMAIN | grep -i php"
echo "   ✓ Test database connections"
echo "   ✓ Check plugin/module compatibility"

if [ "$COMPATIBILITY_WARNING" = true ]; then
    echo ""
    echo "⚠️  REMINDER: Compatibility warning issued!"
    echo "   • Test semua functionality website"
    echo "   • Check for deprecated functions"
    echo "   • Verify all plugins/modules work"
    echo "   • Monitor error logs closely"
fi

echo ""
echo "🔄 Rollback Instructions (jika diperlukan):"
echo "   1. cp $BACKUP_PREFIX.vhost.backup $VHOST_FILE"
echo "   2. mv $OLD_POOL.disabled $OLD_POOL"
echo "   3. rm -f $NEW_POOL"
echo "   4. systemctl restart php$OLDVER-fpm php$NEWVER-fpm"
echo "   5. systemctl reload apache2"
