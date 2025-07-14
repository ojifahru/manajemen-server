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

# Fungsi untuk auto-detect PHP version
auto_detect_php_version() {
    local domain=$1
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    
    if [ ! -f "$vhost_file" ]; then
        echo ""
        return 1
    fi
    
    # Cari versi PHP dari vhost file
    local php_version=$(grep -oP 'php\K\d+\.\d+(?=-fpm)' "$vhost_file" | head -n1)
    
    if [ -n "$php_version" ]; then
        echo "$php_version"
        return 0
    else
        echo ""
        return 1
    fi
}

# Fungsi untuk mencari backup files
find_backup_files() {
    local username=$1
    local backup_dir="/root/website-config-backups"
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    # Cari backup files terbaru untuk user ini
    local latest_backup=$(ls -t "$backup_dir"/${username}_disable_*.vhost.backup 2>/dev/null | head -n1)
    
    if [ -n "$latest_backup" ]; then
        # Extract base filename
        local base_name=$(basename "$latest_backup" .vhost.backup)
        echo "$backup_dir/$base_name"
        return 0
    else
        return 1
    fi
}

# Fungsi untuk cek maintenance mode
check_maintenance_mode() {
    local domain=$1
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    local maintenance_backup="$vhost_file.maintenance_backup"
    
    if [ -f "$maintenance_backup" ]; then
        echo "maintenance"
        return 0
    elif grep -q "/var/www/maintenance" "$vhost_file" 2>/dev/null; then
        echo "maintenance"
        return 0
    else
        echo "normal"
        return 1
    fi
}

# Fungsi untuk menampilkan status website
show_website_status() {
    local domain=$1
    local username=$2
    local php_version=$3
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    local user_home="/home/$username"
    
    echo ""
    echo "📋 STATUS WEBSITE SAAT INI:"
    echo "=========================="
    echo "🌐 Domain        : $domain"
    echo "👤 Username      : $username"
    echo "🛠️  PHP Version   : $php_version"
    echo "📁 Home Directory: $user_home"
    echo "📄 VHost File    : $vhost_file"
    
    # Cek Apache status
    if [ -L "/etc/apache2/sites-enabled/$domain.conf" ]; then
        echo "🟢 Apache Status : ENABLED"
    else
        echo "🔴 Apache Status : DISABLED"
    fi
    
    # Cek maintenance mode
    local mode=$(check_maintenance_mode "$domain")
    if [ "$mode" = "maintenance" ]; then
        echo "🟡 Current Mode  : MAINTENANCE MODE"
    fi
    
    # Cek pool status
    local pool_file="/etc/php/$php_version/fpm/pool.d/$username.conf"
    local disabled_pool="$pool_file.disabled"
    
    if [ -f "$pool_file" ]; then
        echo "🟢 Pool Status   : ACTIVE"
    elif [ -f "$disabled_pool" ]; then
        echo "🔴 Pool Status   : DISABLED"
    else
        echo "❌ Pool Status   : NOT FOUND"
    fi
    
    # Cek user status
    if id "$username" &>/dev/null; then
        local user_shell=$(getent passwd "$username" | cut -d: -f7)
        if [[ "$user_shell" == "/bin/bash" ]]; then
            echo "🟢 User Access   : SSH ENABLED"
        else
            echo "🔴 User Access   : SSH BLOCKED"
        fi
    else
        echo "❌ User Status   : NOT FOUND"
    fi
    
    # Cek disable info file
    local disable_info="/home/$username/.website_disabled_info"
    if [ -f "$disable_info" ]; then
        echo "📄 Disable Info : FOUND"
        local disable_date=$(grep "Disabled Date:" "$disable_info" | cut -d: -f2- | xargs)
        local disable_mode=$(grep "Mode:" "$disable_info" | cut -d: -f2 | xargs)
        echo "   📅 Disabled   : $disable_date"
        echo "   🔧 Mode       : $disable_mode"
    fi
    
    echo ""
}

# === INPUT dengan validasi ===
while true; do
    read -p "Masukkan nama domain yang ingin DIAKTIFKAN (contoh: mysite.local): " DOMAIN
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

# Auto-detect PHP version
echo "🔍 Mendeteksi versi PHP..."
AUTO_PHP_VERSION=$(auto_detect_php_version "$DOMAIN")

if [ -n "$AUTO_PHP_VERSION" ]; then
    echo "✅ Terdeteksi PHP version: $AUTO_PHP_VERSION"
    read -p "Gunakan PHP $AUTO_PHP_VERSION? (Y/n): " USE_AUTO
    if [[ "$USE_AUTO" =~ ^[Nn]$ ]]; then
        read -p "Masukkan versi PHP manual (contoh: 7.4, 8.1): " PHPVER
    else
        PHPVER="$AUTO_PHP_VERSION"
    fi
else
    echo "⚠️ Tidak dapat mendeteksi versi PHP otomatis"
    read -p "Masukkan versi PHP yang digunakan (contoh: 7.4, 8.1): " PHPVER
fi

# Validasi PHP version
if [[ ! $PHPVER =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Format versi PHP tidak valid: $PHPVER"
    exit 1
fi

# Tampilkan status saat ini
show_website_status "$DOMAIN" "$USERNAME" "$PHPVER"

# Cek apakah website sudah enabled
ALREADY_ENABLED=true
if [ ! -L "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
    ALREADY_ENABLED=false
fi

POOL_FILE="/etc/php/$PHPVER/fpm/pool.d/$USERNAME.conf"
if [ ! -f "$POOL_FILE" ]; then
    ALREADY_ENABLED=false
fi

if [ "$ALREADY_ENABLED" = true ]; then
    local mode=$(check_maintenance_mode "$DOMAIN")
    if [ "$mode" = "maintenance" ]; then
        echo "⚠️ Website dalam maintenance mode."
    else
        echo "⚠️ Website $DOMAIN sepertinya sudah aktif."
    fi
    echo ""
    read -p "Tetap lanjutkan untuk memastikan semua komponen aktif? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Operasi dibatalkan."
        exit 0
    fi
fi

echo ""
echo "✅ Mengaktifkan website $DOMAIN..."

# === Handle maintenance mode restoration ===
echo ""
echo "🔧 Memeriksa maintenance mode..."

MAINTENANCE_BACKUP="$VHOST_FILE.maintenance_backup"
if [ -f "$MAINTENANCE_BACKUP" ]; then
    echo "🔄 Keluar dari maintenance mode..."
    
    # Restore original vhost dari maintenance backup
    if mv "$MAINTENANCE_BACKUP" "$VHOST_FILE"; then
        echo "✅ Original vhost configuration direstore"
        log_action "Restored vhost from maintenance mode for $DOMAIN"
    else
        echo "❌ Gagal restore vhost dari maintenance backup"
        log_action "ERROR: Failed to restore vhost from maintenance backup"
    fi
    
    # Hapus maintenance directory jika ada
    if [ -d "/var/www/maintenance" ]; then
        rm -rf "/var/www/maintenance"
        echo "✅ Maintenance directory dihapus"
    fi
elif grep -q "/var/www/maintenance" "$VHOST_FILE" 2>/dev/null; then
    echo "⚠️ Detected maintenance mode tanpa backup file"
    
    if [ "$BACKUP_FOUND" = true ] && [ -f "$BACKUP_BASE.vhost.backup" ]; then
        echo "🔄 Restore vhost dari backup..."
        if cp "$BACKUP_BASE.vhost.backup" "$VHOST_FILE"; then
            echo "✅ VHost direstore dari backup"
            log_action "Restored vhost from backup for $DOMAIN"
        else
            echo "❌ Gagal restore vhost dari backup"
        fi
    else
        echo "⚠️ Tidak ada backup vhost, maintenance mode tetap aktif"
        echo "   Manual intervention diperlukan untuk mengembalikan original config"
    fi
else
    echo "✅ Website tidak dalam maintenance mode"
fi

# === Aktifkan Apache vhost ===
echo ""
echo "🌐 Mengaktifkan Apache vhost..."

if [ -f "$VHOST_FILE" ]; then
    # Test konfigurasi Apache sebelum enable
    if apache2ctl configtest 2>/dev/null; then
        if a2ensite "$DOMAIN.conf" &>/dev/null; then
            echo "✅ Apache vhost berhasil diaktifkan"
            log_action "Apache vhost enabled for $DOMAIN"
        else
            echo "❌ Gagal mengaktifkan Apache vhost"
            log_action "ERROR: Failed to enable Apache vhost for $DOMAIN"
        fi
    else
        echo "❌ Konfigurasi Apache tidak valid"
        echo "   Periksa file vhost: $VHOST_FILE"
        log_action "ERROR: Invalid Apache configuration for $DOMAIN"
    fi
else
    echo "❌ File vhost tidak ditemukan: $VHOST_FILE"
    log_action "ERROR: VHost file not found: $VHOST_FILE"
fi

# Reload Apache
if systemctl reload apache2 2>/dev/null; then
    echo "✅ Apache configuration direload"
else
    echo "❌ Gagal reload Apache"
    log_action "ERROR: Failed to reload Apache"
fi

# === Aktifkan PHP-FPM pool ===
echo ""
echo "⚙️ Mengaktifkan PHP-FPM pool..."

# Cek apakah service PHP-FPM berjalan
if ! systemctl is-active php$PHPVER-fpm &>/dev/null; then
    echo "⚠️ Service php$PHPVER-fpm tidak aktif, mencoba start..."
    if systemctl start php$PHPVER-fpm 2>/dev/null; then
        echo "✅ Service php$PHPVER-fpm berhasil distart"
    else
        echo "❌ Gagal start service php$PHPVER-fpm"
        log_action "ERROR: Failed to start php$PHPVER-fpm service"
    fi
fi

# Restore pool dari disabled atau backup
POOL_RESTORED=false

if [ -f "$DISABLED_POOL_FILE" ]; then
    echo "🔄 Restore pool dari disabled file..."
    if mv "$DISABLED_POOL_FILE" "$POOL_FILE"; then
        echo "✅ PHP-FPM pool direstore dari disabled file"
        POOL_RESTORED=true
        log_action "PHP-FPM pool restored from disabled file: $DISABLED_POOL_FILE"
    else
        echo "❌ Gagal restore pool dari disabled file"
        log_action "ERROR: Failed to restore pool from disabled file"
    fi
elif [ "$BACKUP_FOUND" = true ] && [ -f "$BACKUP_BASE.pool.backup" ]; then
    echo "🔄 Restore pool dari backup..."
    if cp "$BACKUP_BASE.pool.backup" "$POOL_FILE"; then
        echo "✅ PHP-FPM pool direstore dari backup"
        POOL_RESTORED=true
        log_action "PHP-FPM pool restored from backup: $BACKUP_BASE.pool.backup"
    else
        echo "❌ Gagal restore pool dari backup"
        log_action "ERROR: Failed to restore pool from backup"
    fi
elif [ -f "$POOL_FILE" ]; then
    echo "✅ PHP-FPM pool sudah ada dan aktif"
    POOL_RESTORED=true
else
    echo "❌ PHP-FPM pool tidak ditemukan dan tidak ada backup"
    echo "   Manual intervention diperlukan untuk membuat pool config"
    log_action "ERROR: No PHP-FPM pool found and no backup available"
fi

# Restart PHP-FPM jika pool direstore
if [ "$POOL_RESTORED" = true ]; then
    if systemctl restart php$PHPVER-fpm 2>/dev/null; then
        echo "✅ PHP-FPM service direstart"
        
        # Tunggu sebentar dan cek socket
        sleep 2
        SOCKET_FILE="/run/php/php$PHPVER-fpm-$USERNAME.sock"
        if [ -S "$SOCKET_FILE" ]; then
            echo "✅ PHP-FPM socket aktif: $SOCKET_FILE"
        else
            echo "⚠️ PHP-FPM socket tidak ditemukan: $SOCKET_FILE"
        fi
    else
        echo "❌ Gagal restart PHP-FPM service"
        log_action "ERROR: Failed to restart php$PHPVER-fpm service"
    fi
fi

# === Aktifkan akses user SSH ===
echo ""
echo "🔒 Mengaktifkan akses SSH user..."

if id "$USERNAME" &>/dev/null; then
    CURRENT_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
    
    if [[ "$CURRENT_SHELL" != "/bin/bash" ]]; then
        # Coba restore dari backup dulu
        if [ "$BACKUP_FOUND" = true ] && [ -f "$BACKUP_BASE.shell.backup" ]; then
            echo "🔄 Restore shell dari backup..."
            ORIGINAL_SHELL=$(cat "$BACKUP_BASE.shell.backup" | cut -d: -f2)
            if [ -n "$ORIGINAL_SHELL" ] && [ "$ORIGINAL_SHELL" != "/usr/sbin/nologin" ]; then
                if usermod -s "$ORIGINAL_SHELL" "$USERNAME" 2>/dev/null; then
                    echo "✅ Shell user direstore ke: $ORIGINAL_SHELL"
                    log_action "User shell restored to $ORIGINAL_SHELL for $USERNAME"
                else
                    echo "❌ Gagal restore shell dari backup, menggunakan /bin/bash"
                    usermod -s /bin/bash "$USERNAME" 2>/dev/null
                fi
            else
                usermod -s /bin/bash "$USERNAME" 2>/dev/null
                echo "✅ Shell user diset ke /bin/bash"
            fi
        else
            # Default ke /bin/bash
            if usermod -s /bin/bash "$USERNAME" 2>/dev/null; then
                echo "✅ Shell user diaktifkan (/bin/bash)"
                log_action "User shell enabled for $USERNAME"
            else
                echo "❌ Gagal mengaktifkan shell user"
                log_action "ERROR: Failed to enable user shell for $USERNAME"
            fi
        fi
    else
        echo "✅ Shell user sudah aktif (/bin/bash)"
    fi
else
    echo "❌ User $USERNAME tidak ditemukan"
    log_action "ERROR: User $USERNAME not found"
fi

# === Hapus file disable info ===
echo ""
echo "🧹 Membersihkan file disable info..."

DISABLE_INFO_FILE="/home/$USERNAME/.website_disabled_info"
if [ -f "$DISABLE_INFO_FILE" ]; then
    if rm -f "$DISABLE_INFO_FILE"; then
        echo "✅ File disable info dihapus"
    else
        echo "⚠️ Gagal menghapus file disable info"
    fi
fi

# === Test dan verifikasi ===
echo ""
echo "🧪 Memverifikasi website..."

# Test Apache config
if apache2ctl configtest 2>/dev/null; then
    echo "✅ Konfigurasi Apache valid"
else
    echo "❌ Konfigurasi Apache tidak valid"
fi

# Test website accessibility
sleep 2  # Tunggu services fully restart

if curl -s -k "https://$DOMAIN" -o /dev/null 2>/dev/null; then
    echo "✅ Website dapat diakses via HTTPS"
elif curl -s "http://$DOMAIN" -o /dev/null 2>/dev/null; then
    echo "✅ Website dapat diakses via HTTP"
else
    echo "⚠️ Website tidak dapat diakses dari localhost"
    echo "   Periksa konfigurasi DNS atau hosts file"
fi

# Cek PHP-FPM socket
SOCKET_FILE="/run/php/php$PHPVER-fpm-$USERNAME.sock"
if [ -S "$SOCKET_FILE" ]; then
    echo "✅ PHP-FPM socket aktif"
else
    echo "❌ PHP-FPM socket tidak aktif"
fi

# Verifikasi semua services
if systemctl is-active apache2 &>/dev/null && systemctl is-active php$PHPVER-fpm &>/dev/null; then
    echo "✅ Semua services berjalan normal"
else
    echo "⚠️ Ada services yang tidak berjalan normal"
fi

log_action "Website enable completed for $DOMAIN"

echo ""
echo "🎉 Website $DOMAIN berhasil DIAKTIFKAN!"
echo "======================================="
echo "📊 Status Summary:"

# Check final status
if [ -L "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
    echo "   🌐 Apache VHost : ✅ ENABLED"
else
    echo "   🌐 Apache VHost : ❌ DISABLED"
fi

if [ -f "$POOL_FILE" ]; then
    echo "   ⚙️  PHP-FPM Pool : ✅ ACTIVE"
else
    echo "   ⚙️  PHP-FPM Pool : ❌ INACTIVE"
fi

if id "$USERNAME" &>/dev/null; then
    USER_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
    if [[ "$USER_SHELL" == "/bin/bash" ]]; then
        echo "   🔒 SSH Access   : ✅ ENABLED"
    else
        echo "   🔒 SSH Access   : ❌ BLOCKED"
    fi
fi

if [ -S "/run/php/php$PHPVER-fpm-$USERNAME.sock" ]; then
    echo "   🔌 PHP Socket   : ✅ ACTIVE"
else
    echo "   🔌 PHP Socket   : ❌ INACTIVE"
fi

echo ""
echo "🌍 Akses Website:"
echo "   HTTP  : http://$DOMAIN"
echo "   HTTPS : https://$DOMAIN"
echo ""

if [ "$BACKUP_FOUND" = true ]; then
    echo "📦 Backup Files (dapat dihapus jika tidak diperlukan):"
    echo "   📁 VHost Backup : $BACKUP_BASE.vhost.backup"
    echo "   ⚙️  Pool Backup  : $BACKUP_BASE.pool.backup"
    echo "   🐚 Shell Backup : $BACKUP_BASE.shell.backup"
    echo ""
fi

echo "📋 Management Commands:"
echo "   • Check status  : ./check-php-versions.sh -s"
echo "   • Disable again : ./disable-website.sh"
echo "   • View logs     : tail -f /var/log/website-management.log"
echo "   • Test website  : curl -k https://$DOMAIN"
echo ""

echo "💡 Tips:"
echo "   • Website mungkin perlu beberapa detik untuk fully aktif"
echo "   • Jika ada masalah, cek Apache dan PHP-FPM logs"
echo "   • Backup files dapat dihapus setelah konfirmasi website berjalan normal"
echo ""

# Tampilkan peringatan jika ada yang tidak aktif
WARNINGS=false
if [ ! -L "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
    echo "⚠️  WARNING: Apache vhost tidak aktif"
    WARNINGS=true
fi

if [ ! -f "$POOL_FILE" ]; then
    echo "⚠️  WARNING: PHP-FPM pool tidak aktif"
    WARNINGS=true
fi

if [ ! -S "/run/php/php$PHPVER-fpm-$USERNAME.sock" ]; then
    echo "⚠️  WARNING: PHP-FPM socket tidak aktif"
    WARNINGS=true
fi

if [ "$WARNINGS" = true ]; then
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Cek logs: journalctl -u apache2 -u php$PHPVER-fpm"
    echo "   2. Test config: apache2ctl configtest"
    echo "   3. Restart services: systemctl restart apache2 php$PHPVER-fpm"
    echo "   4. Manual intervention mungkin diperlukan"
fi

DISABLED_POOL_FILE="${POOL_FILE}.disabled"

# Cari backup files
echo "🔍 Mencari backup files..."
BACKUP_BASE=$(find_backup_files "$USERNAME")

if [ -n "$BACKUP_BASE" ]; then
    echo "✅ Ditemukan backup files: $BACKUP_BASE.*"
    BACKUP_FOUND=true
else
    echo "⚠️ Backup files tidak ditemukan"
    BACKUP_FOUND=false
fi

# Konfirmasi
echo ""
echo "⚡ Operasi ini akan:"
echo "   • Mengaktifkan Apache vhost"
echo "   • Mengaktifkan PHP-FPM pool"
echo "   • Mengaktifkan login user SSH"

if [ "$(check_maintenance_mode "$DOMAIN")" = "maintenance" ]; then
    echo "   • Keluar dari maintenance mode"
fi

if [ "$BACKUP_FOUND" = true ]; then
    echo "   • Restore dari backup files (jika diperlukan)"
fi

echo ""
read -p "Apakah Anda yakin ingin mengaktifkan website $DOMAIN? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Operasi dibatalkan."
    exit 0
fi

log_action "Starting website enable for $DOMAIN (PHP $PHPVER, User: $USERNAME)"
