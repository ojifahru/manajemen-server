#!/bin/bash

# Fungsi untuk logging
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "/var/log/website-management.log"
}

#USERNAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')
POOL_FILE="/etc/php/$PHPVER/fpm/pool.d/$USERNAME.conf"
DISABLED_POOL_FILE="${POOL_FILE}.disabled"
BACKUP_DIR="/root/website-config-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

# Buat direktori backup
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Tampilkan informasi website
show_website_info "$DOMAIN" "$USERNAME" "$PHPVER"

# Cek apakah website sudah disabled
if [ ! -L "/etc/apache2/sites-enabled/$DOMAIN.conf" ] && [ ! -f "$POOL_FILE" ]; then
    echo "⚠️ Website $DOMAIN sepertinya sudah dinonaktifkan."
    echo ""
    read -p "Tetap lanjutkan untuk memastikan semua komponen dinonaktifkan? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Operasi dibatalkan."
        exit 0
    fi
fi

# Konfirmasi
echo "⚠️ Operasi ini akan:"
echo "   • Menonaktifkan Apache vhost"
echo "   • Menonaktifkan PHP-FPM pool"
echo "   • Memblokir login user SSH"
echo "   • Menghentikan proses user yang berjalan"
echo ""

read -p "Apakah Anda yakin ingin menonaktifkan website $DOMAIN? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Operasi dibatalkan."
    exit 0
fi

# Tanyakan mode disable
echo ""
echo "Pilih mode disable:"
echo "1. Temporary (dapat diaktifkan kembali dengan mudah)"
echo "2. Maintenance (tampilkan halaman maintenance)"
read -p "Pilih mode (1-2): " DISABLE_MODE

log_action "Starting website disable for $DOMAIN (PHP $PHPVER, User: $USERNAME)"ngsi validasi domain
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

# Fungsi untuk menampilkan informasi website
show_website_info() {
    local domain=$1
    local username=$2
    local php_version=$3
    local vhost_file="/etc/apache2/sites-available/$domain.conf"
    local user_home="/home/$username"
    
    echo ""
    echo "📋 INFORMASI WEBSITE:"
    echo "===================="
    echo "🌐 Domain        : $domain"
    echo "👤 Username      : $username"
    echo "🛠️  PHP Version   : $php_version"
    echo "📁 Home Directory: $user_home"
    echo "📄 VHost File    : $vhost_file"
    
    # Cek status saat ini
    if [ -L "/etc/apache2/sites-enabled/$domain.conf" ]; then
        echo "🟢 Website Status: AKTIF"
    else
        echo "🔴 Website Status: SUDAH NONAKTIF"
    fi
    
    # Cek pool status
    local pool_file="/etc/php/$php_version/fpm/pool.d/$username.conf"
    if [ -f "$pool_file" ]; then
        echo "🟢 Pool Status   : AKTIF"
    elif [ -f "$pool_file.disabled" ]; then
        echo "🟡 Pool Status   : NONAKTIF"
    else
        echo "🔴 Pool Status   : TIDAK DITEMUKAN"
    fi
    
    # Cek user status
    if id "$username" &>/dev/null; then
        local user_shell=$(getent passwd "$username" | cut -d: -f7)
        if [[ "$user_shell" == "/bin/bash" ]]; then
            echo "🟢 User Access   : LOGIN AKTIF"
        else
            echo "🔴 User Access   : LOGIN DIBLOKIR"
        fi
        
        # Cek proses yang berjalan
        local running_processes=$(pgrep -u "$username" 2>/dev/null | wc -l)
        echo "🔧 Running Proc  : $running_processes"
    else
        echo "❌ User Status   : TIDAK DITEMUKAN"
    fi
    
    # Cek ukuran folder
    if [ -d "$user_home" ]; then
        local folder_size=$(du -sh "$user_home" 2>/dev/null | cut -f1)
        echo "📊 Folder Size   : $folder_size"
    fi
    
    echo ""
}

# === INPUT dengan validasi ===
while true; do
    read -p "Masukkan nama domain yang ingin DINONAKTIFKAN (contoh: mysite.local): " DOMAIN
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

# Cek apakah service PHP-FPM ada
if ! systemctl list-units --type=service | grep -q "php$PHPVER-fpm.service"; then
    echo "❌ Service php$PHPVER-fpm tidak ditemukan!"
    exit 1
fi

USERNAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')
POOL_FILE="/etc/php/$PHPVER/fpm/pool.d/$USERNAME.conf"
DISABLED_POOL_FILE="${POOL_FILE}.disabled"

echo ""
echo "🚫 Menonaktifkan website $DOMAIN..."

# === Backup konfigurasi ===
echo "📦 Membuat backup konfigurasi..."
BACKUP_PREFIX="$BACKUP_DIR/${USERNAME}_disable_$DATE"

# Backup Apache vhost
if [ -f "$VHOST_FILE" ]; then
    cp "$VHOST_FILE" "$BACKUP_PREFIX.vhost.backup"
    echo "✅ Apache vhost dibackup"
fi

# Backup PHP-FPM pool jika ada
if [ -f "$POOL_FILE" ]; then
    cp "$POOL_FILE" "$BACKUP_PREFIX.pool.backup"
    echo "✅ PHP-FPM pool dibackup"
fi

# === Hentikan proses user yang berjalan ===
echo ""
echo "🛑 Menghentikan proses user..."
if id "$USERNAME" &>/dev/null; then
    RUNNING_PROCESSES=$(pgrep -u "$USERNAME" 2>/dev/null | wc -l)
    
    if [ "$RUNNING_PROCESSES" -gt 0 ]; then
        echo "🔍 Ditemukan $RUNNING_PROCESSES proses berjalan untuk user '$USERNAME'"
        
        # Graceful shutdown dengan SIGTERM
        pkill -TERM -u "$USERNAME" 2>/dev/null
        echo "✅ Sinyal TERM dikirim ke semua proses"
        
        # Tunggu 3 detik
        sleep 3
        
        # Force kill jika masih ada proses
        REMAINING=$(pgrep -u "$USERNAME" 2>/dev/null | wc -l)
        if [ "$REMAINING" -gt 0 ]; then
            pkill -KILL -u "$USERNAME" 2>/dev/null
            echo "✅ Force kill proses yang tersisa"
        fi
        
        echo "✅ Semua proses user dihentikan"
        log_action "Stopped $RUNNING_PROCESSES processes for user $USERNAME"
    else
        echo "✅ Tidak ada proses yang berjalan"
    fi
fi

# === Disable Apache vhost ===
echo ""
echo "🌐 Menonaktifkan Apache vhost..."

if [ "$DISABLE_MODE" = "2" ]; then
    # Mode maintenance - buat halaman maintenance
    echo "🔧 Membuat halaman maintenance..."
    
    MAINTENANCE_DIR="/var/www/maintenance"
    mkdir -p "$MAINTENANCE_DIR"
    
    cat > "$MAINTENANCE_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Website Sedang Maintenance - $DOMAIN</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center min-h-screen">
    <div class="bg-white p-10 rounded-2xl shadow-xl max-w-lg text-center">
        <div class="mb-6">
            <div class="mx-auto w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mb-4">
                <span class="text-3xl">🔧</span>
            </div>
            <h1 class="text-2xl font-bold text-gray-800 mb-2">Website Sedang Maintenance</h1>
            <p class="text-gray-600">$DOMAIN</p>
        </div>
        
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
            <p class="text-sm text-gray-700">
                Kami sedang melakukan pemeliharaan sistem untuk meningkatkan performa website.
                Silakan kembali lagi dalam beberapa saat.
            </p>
        </div>
        
        <div class="text-xs text-gray-400">
            Maintenance started: $(date)
        </div>
    </div>
</body>
</html>
EOF
    
    # Backup vhost original dan ganti dengan maintenance
    if [ -f "$VHOST_FILE" ]; then
        cp "$VHOST_FILE" "$VHOST_FILE.maintenance_backup"
        
        # Update DocumentRoot ke maintenance directory
        sed -i "s|DocumentRoot.*|DocumentRoot $MAINTENANCE_DIR|g" "$VHOST_FILE"
        
        # Comment out PHP handler
        sed -i 's|^\(\s*<FilesMatch.*php.*>\)|# \1|g' "$VHOST_FILE"
        sed -i 's|^\(\s*SetHandler.*php.*\)|# \1|g' "$VHOST_FILE"
        sed -i 's|^\(\s*</FilesMatch>\)|# \1|g' "$VHOST_FILE"
        
        echo "✅ Mode maintenance diaktifkan"
        log_action "Maintenance mode enabled for $DOMAIN"
    fi
else
    # Mode normal - disable site
    if [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
        if a2dissite "$DOMAIN.conf" &>/dev/null; then
            echo "✅ Apache vhost dinonaktifkan"
            log_action "Apache vhost disabled for $DOMAIN"
        else
            echo "❌ Gagal menonaktifkan Apache vhost"
        fi
    else
        echo "⚠️ Apache vhost sudah dinonaktifkan"
    fi
fi

# Reload Apache
if systemctl reload apache2 2>/dev/null; then
    echo "✅ Apache configuration direload"
else
    echo "❌ Gagal reload Apache"
    log_action "ERROR: Failed to reload Apache"
fi

# === Disable PHP-FPM pool ===
echo ""
echo "⚙️ Menonaktifkan PHP-FPM pool..."

if [ -f "$POOL_FILE" ]; then
    if mv "$POOL_FILE" "$DISABLED_POOL_FILE"; then
        echo "✅ PHP-FPM pool dinonaktifkan: $DISABLED_POOL_FILE"
        log_action "PHP-FPM pool disabled: $POOL_FILE -> $DISABLED_POOL_FILE"
        
        # Restart PHP-FPM service
        if systemctl restart php$PHPVER-fmp 2>/dev/null; then
            echo "✅ PHP-FPM service direstart"
        else
            echo "⚠️ Gagal restart PHP-FPM service"
            log_action "WARNING: Failed to restart php$PHPVER-fpm"
        fi
    else
        echo "❌ Gagal menonaktifkan PHP-FPM pool"
        log_action "ERROR: Failed to disable PHP-FPM pool"
    fi
elif [ -f "$DISABLED_POOL_FILE" ]; then
    echo "⚠️ PHP-FPM pool sudah dinonaktifkan"
else
    echo "⚠️ PHP-FPM pool tidak ditemukan"
fi

# === Blokir akses user SSH ===
echo ""
echo "🔒 Memblokir akses SSH user..."

if id "$USERNAME" &>/dev/null; then
    # Backup shell user
    CURRENT_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
    echo "$USERNAME:$CURRENT_SHELL" > "$BACKUP_PREFIX.shell.backup"
    
    if usermod -s /usr/sbin/nologin "$USERNAME" 2>/dev/null; then
        echo "✅ Login SSH user diblokir"
        log_action "SSH login blocked for user $USERNAME"
    else
        echo "❌ Gagal memblokir login SSH user"
        log_action "ERROR: Failed to block SSH login for user $USERNAME"
    fi
else
    echo "⚠️ User $USERNAME tidak ditemukan"
fi

# === Buat file disable info ===
echo ""
echo "📝 Membuat file informasi disable..."

DISABLE_INFO_FILE="/home/$USERNAME/.website_disabled_info"
if [ -d "/home/$USERNAME" ]; then
    cat > "$DISABLE_INFO_FILE" <<EOF
WEBSITE DISABLED INFORMATION
===========================
Domain: $DOMAIN
Disabled Date: $(date)
Disabled By: $(whoami)
Mode: $([ "$DISABLE_MODE" = "2" ] && echo "Maintenance" || echo "Temporary")
PHP Version: $PHPVER
Username: $USERNAME

Backup Files:
- Apache VHost: $BACKUP_PREFIX.vhost.backup
- PHP-FPM Pool: $BACKUP_PREFIX.pool.backup
- User Shell: $BACKUP_PREFIX.shell.backup

To Re-enable:
Run the enable-website.sh script with domain: $DOMAIN

Status:
- Apache VHost: $([ "$DISABLE_MODE" = "2" ] && echo "Maintenance Mode" || echo "Disabled")
- PHP-FPM Pool: Disabled
- SSH Access: Blocked
- Processes: Stopped
EOF
    
    chown "$USERNAME:$USERNAME" "$DISABLE_INFO_FILE" 2>/dev/null
    echo "✅ File informasi disable dibuat: $DISABLE_INFO_FILE"
fi

# === Test dan verifikasi ===
echo ""
echo "🧪 Memverifikasi disable status..."

# Test website accessibility
if [ "$DISABLE_MODE" = "2" ]; then
    # Test maintenance page
    if curl -s -k "https://$DOMAIN" | grep -q "maintenance" 2>/dev/null; then
        echo "✅ Halaman maintenance dapat diakses"
    elif curl -s "http://$DOMAIN" | grep -q "maintenance" 2>/dev/null; then
        echo "✅ Halaman maintenance dapat diakses via HTTP"
    else
        echo "⚠️ Maintenance page tidak dapat diakses dari localhost"
    fi
else
    # Test site inaccessibility
    if curl -s -k "https://$DOMAIN" -o /dev/null 2>/dev/null; then
        echo "⚠️ Website masih dapat diakses (mungkin ada cache atau DNS delay)"
    else
        echo "✅ Website tidak dapat diakses"
    fi
fi

# Verify processes stopped
REMAINING_PROCESSES=$(pgrep -u "$USERNAME" 2>/dev/null | wc -l)
if [ "$REMAINING_PROCESSES" -eq 0 ]; then
    echo "✅ Semua proses user telah dihentikan"
else
    echo "⚠️ Masih ada $REMAINING_PROCESSES proses yang berjalan"
fi

# Verify PHP-FPM pool
if [ ! -f "$POOL_FILE" ] && [ -f "$DISABLED_POOL_FILE" ]; then
    echo "✅ PHP-FPM pool berhasil dinonaktifkan"
else
    echo "⚠️ Status PHP-FPM pool tidak sesuai expected"
fi

log_action "Website disable completed for $DOMAIN (Mode: $([ "$DISABLE_MODE" = "2" ] && echo "Maintenance" || echo "Temporary"))"

echo ""
echo "🎉 Website $DOMAIN berhasil DINONAKTIFKAN!"
echo "=========================================="
echo "📊 Status Summary:"
echo "   🌐 Apache VHost : $([ "$DISABLE_MODE" = "2" ] && echo "Maintenance Mode" || echo "Disabled")"
echo "   ⚙️  PHP-FPM Pool : Disabled"
echo "   🔒 SSH Access   : Blocked"
echo "   🛑 User Process : Stopped"
echo "   📦 Backup Files : $BACKUP_PREFIX.*"
echo ""

if [ "$DISABLE_MODE" = "2" ]; then
    echo "🔧 Mode: MAINTENANCE"
    echo "   • Website menampilkan halaman maintenance"
    echo "   • Visitors akan melihat pesan maintenance"
    echo "   • Original config dibackup di: $VHOST_FILE.maintenance_backup"
    echo ""
    echo "🔄 Untuk keluar dari maintenance mode:"
    echo "   1. Gunakan: ./enable-website.sh"
    echo "   2. Atau restore manual: mv $VHOST_FILE.maintenance_backup $VHOST_FILE"
else
    echo "🚫 Mode: TEMPORARY DISABLE"
    echo "   • Website sepenuhnya dinonaktifkan"
    echo "   • Dapat diaktifkan kembali dengan mudah"
fi

echo ""
echo "📋 Backup Information:"
echo "   📁 Apache VHost : $BACKUP_PREFIX.vhost.backup"
echo "   ⚙️  PHP-FPM Pool : $BACKUP_PREFIX.pool.backup"
echo "   🐚 User Shell   : $BACKUP_PREFIX.shell.backup"
echo "   📄 Disable Info : $DISABLE_INFO_FILE"
echo ""
echo "🔄 Untuk mengaktifkan kembali:"
echo "   ./enable-website.sh"
echo "   (Script akan auto-detect backup files)"
echo ""
echo "📊 Monitoring:"
echo "   • Check status: ./check-php-versions.sh -s"
echo "   • View logs: tail -f /var/log/website-management.log"
