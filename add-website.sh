#!/bin/bash

# Debug mode - uncomment untuk debugging
# set -x

# Exit on error untuk debugging
set -e

# Fungsi untuk logging
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "/var/log/website-management.log"
}

# Fungsi untuk debug logging
debug_log() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: $1" | tee -a "/var/log/website-management.log"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Script harus dijalankan sebagai root"
    echo "   Gunakan: sudo $0"
    exit 1
fi

# Fungsi untuk cleanup jika error
cleanup_on_error() {
    echo ""
    echo "🚨 ERROR DETECTED - Starting cleanup process..."
    log_action "ERROR: Cleaning up failed website creation for $DOMAIN"
    
    # Hapus user jika baru dibuat
    if [ "$USER_CREATED" = "true" ] && id "$USERNAME" &>/dev/null; then
        echo "🧹 Removing Linux user: $USERNAME"
        if userdel -r "$USERNAME" 2>/dev/null; then
            echo "   ✅ User $USERNAME removed successfully"
            log_action "Removed user $USERNAME"
        else
            echo "   ⚠️ Failed to remove user $USERNAME"
            log_action "WARNING: Failed to remove user $USERNAME"
        fi
    fi
    
    # Hapus database jika baru dibuat
    if [ "$DB_CREATED" = "true" ]; then
        echo "🧹 Removing MySQL database: $DB_NAME"
        if mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null; then
            echo "   ✅ Database $DB_NAME removed successfully"
        else
            echo "   ⚠️ Failed to remove database $DB_NAME"
        fi
        
        echo "🧹 Removing MySQL user: $DB_USER"
        if mysql -uroot -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null; then
            echo "   ✅ User $DB_USER removed successfully"
        else
            echo "   ⚠️ Failed to remove user $DB_USER"
        fi
        
        log_action "Removed database $DB_NAME and user $DB_USER"
    fi
    
    # Hapus file konfigurasi Apache
    if [ -f "$VHOST_FILE" ]; then
        echo "🧹 Removing Apache configuration: $VHOST_FILE"
        if rm -f "$VHOST_FILE" 2>/dev/null; then
            echo "   ✅ Apache config removed"
        else
            echo "   ⚠️ Failed to remove Apache config"
        fi
        
        if a2dissite "$DOMAIN.conf" &>/dev/null; then
            echo "   ✅ Apache site disabled"
        else
            echo "   ⚠️ Failed to disable Apache site"
        fi
    fi
    
    # Hapus file konfigurasi PHP-FPM
    if [ -f "$POOL_CONF" ]; then
        echo "🧹 Removing PHP-FPM pool: $POOL_CONF"
        if rm -f "$POOL_CONF" 2>/dev/null; then
            echo "   ✅ PHP-FPM pool removed"
        else
            echo "   ⚠️ Failed to remove PHP-FPM pool"
        fi
    fi
    
    # Reload services
    echo "🔄 Reloading services..."
    if systemctl reload apache2 2>/dev/null; then
        echo "   ✅ Apache reloaded"
    else
        echo "   ⚠️ Failed to reload Apache"
    fi
    
    if systemctl restart php$PHPVER-fpm 2>/dev/null; then
        echo "   ✅ PHP-FPM restarted"
    else
        echo "   ⚠️ Failed to restart PHP-FPM"
    fi
    
    echo ""
    echo "🛑 Cleanup completed. Check the log for details:"
    echo "   Log file: /var/log/website-management.log"
    echo "   Recent errors: tail -20 /var/log/website-management.log"
    echo ""
    
    log_action "Cleanup process completed for $DOMAIN"
    exit 1
}

# Trap untuk cleanup jika script dihentikan
trap cleanup_on_error ERR

# Fungsi validasi domain
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Format domain tidak valid: $domain"
        echo "   Contoh yang benar: mysite.local, example.com"
        return 1
    fi
    
    # Cek apakah domain sudah ada
    if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
        echo "❌ Domain $domain sudah ada!"
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

# === INPUT dengan validasi ===
while true; do
    read -p "Masukkan nama domain (contoh: mysite.local): " DOMAIN
    if validate_domain "$DOMAIN"; then
        break
    fi
done

while true; do
    read -p "Masukkan versi PHP (contoh: 7.4, 8.1, 8.3): " PHPVER
    if validate_php_version "$PHPVER"; then
        break
    fi
done

USERNAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')

# Validasi username length (maksimal 32 karakter untuk Linux user)
if [ ${#USERNAME} -gt 32 ]; then
    echo "⚠️ Username terlalu panjang (${#USERNAME} karakter): $USERNAME"
    echo "   Maksimal 32 karakter untuk Linux user"
    
    # Truncate and make unique
    USERNAME_BASE=$(echo "$USERNAME" | cut -c1-28)
    USERNAME="${USERNAME_BASE}_$(date +%s | tail -c4)"
    echo "   Username diperpendek menjadi: $USERNAME"
fi

# Informasi yang akan dibuat
echo "📋 Informasi yang akan dibuat:"
echo "   Domain: $DOMAIN"
echo "   Username: $USERNAME (${#USERNAME} karakter)"
echo "   PHP Version: $PHPVER"

USER_HOME="/home/$USERNAME"
DOC_ROOT="$USER_HOME/public_html"
POOL_CONF="/etc/php/$PHPVER/fpm/pool.d/$USERNAME.conf"
SOCK_FILE="/run/php/php$PHPVER-fpm-$USERNAME.sock"
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
PASSLOG="/root/website-passwords.txt"
MYSQLLOG="/root/website-mysql-passwords.txt"
DB_NAME="${USERNAME}_db"
DB_USER="$USERNAME"
BACKUP_DIR="/root/website-config-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

# Validasi database name length (maksimal 64 karakter untuk MySQL)
if [ ${#DB_NAME} -gt 64 ]; then
    echo "⚠️ Database name terlalu panjang: $DB_NAME"
    DB_NAME=$(echo "$DB_NAME" | cut -c1-64)
    echo "   Database name diperpendek menjadi: $DB_NAME"
fi

debug_log "Generated names: USERNAME=$USERNAME, DB_NAME=$DB_NAME, DOC_ROOT=$DOC_ROOT"

# Flag untuk tracking pembuatan resource
USER_CREATED=false
DB_CREATED=false

# Buat direktori backup dan log, set permission
echo "📁 Preparing directories and log files..."
mkdir -p "$BACKUP_DIR" /var/log/php 2>/dev/null

# Set proper permissions
chmod 700 "$BACKUP_DIR" 2>/dev/null || true
chmod 755 /var/log/php 2>/dev/null || true
chown root:adm /var/log/php 2>/dev/null || true

# Create and secure password log files
touch "$PASSLOG" "$MYSQLLOG" 2>/dev/null || true
chmod 600 "$PASSLOG" "$MYSQLLOG" 2>/dev/null || true
chown root:root "$PASSLOG" "$MYSQLLOG" 2>/dev/null || true

echo "✅ Directories and log files prepared"

# Fungsi untuk membuat self-signed certificate
create_self_signed_cert() {
    local domain=$1
    local ssl_dir="/etc/ssl/websites/$domain"
    
    echo "🔐 Membuat self-signed SSL certificate untuk $domain..."
    
    # Buat direktori SSL
    mkdir -p "$ssl_dir"
    
    # Generate private key
    openssl genrsa -out "$ssl_dir/private.key" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "$ssl_dir/private.key" -out "$ssl_dir/fullchain.crt" -days 365 -subj "/CN=$domain"
    
    # Set permissions
    chmod 600 "$ssl_dir/private.key"
    chmod 644 "$ssl_dir/fullchain.crt"
    chown root:root "$ssl_dir/private.key" "$ssl_dir/fullchain.crt"
    
    echo "✅ Self-signed certificate berhasil dibuat"
    echo "   Certificate: $ssl_dir/fullchain.crt"
    echo "   Private Key: $ssl_dir/private.key"
    
    # Set SSL paths
    SSL_CERT_PATH="$ssl_dir/fullchain.crt"
    SSL_KEY_PATH="$ssl_dir/private.key"
}

# Fungsi untuk setup Let's Encrypt
setup_letsencrypt() {
    local domain=$1
    
    echo "🔐 Setting up Let's Encrypt untuk $domain..."
    
    # Pastikan domain dapat diakses (basic website sudah aktif)
    echo "   Memverifikasi domain dapat diakses..."
    
    # Test domain accessibility
    if ! curl -s -I "http://$domain" | grep -q "200\|301\|302"; then
        echo "❌ Domain $domain tidak dapat diakses dari internet"
        echo "   Let's Encrypt memerlukan domain yang dapat diakses public"
        echo "   Pastikan:"
        echo "   - Domain sudah pointing ke IP server ini"
        echo "   - Firewall membuka port 80 dan 443"
        echo "   - Website sudah aktif"
        return 1
    fi
    
    # Generate certificate dengan certbot
    echo "   Generating Let's Encrypt certificate..."
    
    # Stop Apache sementara untuk standalone mode
    systemctl stop apache2
    
    # Generate certificate
    if certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "admin@$domain" --expand; then
        echo "✅ Let's Encrypt certificate berhasil dibuat"
        
        # Set SSL paths
        SSL_CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
        SSL_KEY_PATH="/etc/letsencrypt/live/$domain/privkey.pem"
        
        # Start Apache kembali
        systemctl start apache2
        
        # Setup auto-renewal
        setup_certbot_renewal
        
        return 0
    else
        echo "❌ Gagal membuat Let's Encrypt certificate"
        echo "   Menggunakan self-signed certificate sebagai fallback"
        
        # Start Apache kembali
        systemctl start apache2
        
        # Fallback to self-signed
        create_self_signed_cert "$domain"
        return 1
    fi
}

# Fungsi untuk setup certbot auto-renewal
setup_certbot_renewal() {
    echo "🔄 Setting up auto-renewal untuk Let's Encrypt..."
    
    # Buat systemd timer untuk renewal
    cat > /etc/systemd/system/certbot-renewal.service << 'EOF'
[Unit]
Description=Certbot Renewal
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "systemctl reload apache2"
EOF

    cat > /etc/systemd/system/certbot-renewal.timer << 'EOF'
[Unit]
Description=Run certbot renewal twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable dan start timer
    systemctl daemon-reload
    systemctl enable certbot-renewal.timer
    systemctl start certbot-renewal.timer
    
    echo "✅ Auto-renewal berhasil disetup"
    echo "   Certificate akan auto-renew setiap 12 jam"
}

# Cek apakah certbot tersedia
if ! command -v certbot >/dev/null 2>&1; then
    echo "⚠️ Certbot tidak ditemukan. Menginstall certbot..."
    apt update
    apt install -y certbot python3-certbot-apache
    
    if ! command -v certbot >/dev/null 2>&1; then
        echo "❌ Gagal menginstall certbot"
        exit 1
    fi
    echo "✅ Certbot berhasil diinstall"
fi

# Validasi domain untuk Let's Encrypt (harus public domain)
if [[ "$DOMAIN" == *.local ]] || [[ "$DOMAIN" == localhost* ]] || [[ "$DOMAIN" == *test* ]]; then
    echo "⚠️ Domain lokal terdeteksi: $DOMAIN"
    echo "   Let's Encrypt hanya bekerja untuk domain public yang dapat diakses dari internet"
    echo ""
    echo "Pilih opsi SSL:"
    echo "1. Skip SSL (HTTP only) - untuk development"
    echo "2. Self-signed certificate - untuk testing"
    echo "3. Let's Encrypt - untuk production (domain harus public)"
    echo ""
    read -p "Pilih opsi SSL (1-3): " SSL_OPTION
    
    case $SSL_OPTION in
        1)
            USE_SSL=false
            echo "⚠️ Website akan dibuat tanpa SSL (HTTP only)"
            ;;
        2)
            USE_SSL=true
            SSL_TYPE="self-signed"
            echo "🔐 Akan menggunakan self-signed certificate"
            ;;
        3)
            USE_SSL=true
            SSL_TYPE="letsencrypt"
            echo "🔐 Akan menggunakan Let's Encrypt"
            echo "⚠️ Pastikan domain dapat diakses dari internet"
            ;;
        *)
            echo "❌ Pilihan tidak valid"
            exit 1
            ;;
    esac
else
    USE_SSL=true
    SSL_TYPE="letsencrypt"
    echo "🔐 Domain public terdeteksi. Akan menggunakan Let's Encrypt"
fi

echo ""
echo "🚀 Membuat website untuk domain: $DOMAIN"
echo "📊 Menggunakan PHP: $PHPVER"
echo "👤 Username: $USERNAME"
echo "🗄️ Database: $DB_NAME"
echo ""

echo "💡 Debug Mode:"
echo "   Enable debug: export DEBUG=1"
echo "   Log file: /var/log/website-management.log"
echo "   Backup dir: $BACKUP_DIR"
echo ""

# Konfirmasi sebelum eksekusi
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Operasi dibatalkan."
    exit 0
fi

# === PRE-FLIGHT CHECKS ===
echo "🔍 Melakukan pre-flight checks..."

# Check MySQL connection
echo "   Testing MySQL connection..."
if ! mysql -uroot -e "SELECT 1;" &>/dev/null; then
    echo "   ❌ MySQL tidak dapat diakses sebagai root"
    echo "      Pastikan MySQL berjalan: systemctl status mysql"
    echo "      Test login: mysql -uroot -p"
    exit 1
fi
echo "   ✅ MySQL accessible"

# Check Apache
echo "   Testing Apache..."
if ! systemctl is-active --quiet apache2; then
    echo "   ❌ Apache tidak berjalan"
    echo "      Start Apache: systemctl start apache2"
    exit 1
fi
echo "   ✅ Apache running"

# Check PHP-FPM
echo "   Testing PHP-FPM $PHPVER..."
if ! systemctl is-active --quiet php$PHPVER-fpm; then
    echo "   ❌ PHP-FPM $PHPVER tidak berjalan"
    echo "      Start PHP-FPM: systemctl start php$PHPVER-fpm"
    exit 1
fi
echo "   ✅ PHP-FPM $PHPVER running"

# Check required directories
echo "   Checking directories..."
REQUIRED_DIRS=(
    "/etc/apache2/sites-available"
    "/etc/php/$PHPVER/fpm/pool.d"
    "/var/log/apache2"
)

# Check critical directories that must exist
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "   ❌ Critical directory missing: $dir"
        echo "      This indicates missing packages or incorrect installation"
        exit 1
    fi
done

# Create directories that can be created if missing
CREATABLE_DIRS=(
    "/var/log/php"
    "$BACKUP_DIR"
)

echo "   Creating necessary directories..."
for dir in "${CREATABLE_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "   📁 Creating directory: $dir"
        if ! mkdir -p "$dir" 2>/dev/null; then
            echo "   ❌ Failed to create directory: $dir"
            exit 1
        fi
        
        # Set proper permissions for log directory
        if [[ "$dir" == "/var/log/php" ]]; then
            chmod 755 "$dir"
            chown root:adm "$dir" 2>/dev/null || true
        fi
    fi
done

echo "   ✅ All required directories ready"

# Check disk space
echo "   Checking disk space..."
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # Less than 1GB
    echo "   ⚠️ Low disk space: $(df -h / | tail -1 | awk '{print $4}') available"
    echo "      Minimum 1GB recommended"
    read -p "   Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi
echo "   ✅ Disk space sufficient"

echo "✅ Pre-flight checks passed"
echo ""

log_action "Starting website creation for $DOMAIN with PHP $PHPVER"

# === BUAT USER LINUX ===
echo "👤 Membuat user Linux..."
if ! id "$USERNAME" &>/dev/null; then
    PASSWORD=$(openssl rand -base64 12)
    
    if ! useradd -m -d "$USER_HOME" -s /bin/bash "$USERNAME"; then
        echo "❌ Gagal membuat user $USERNAME"
        exit 1
    fi
    
    if ! echo "$USERNAME:$PASSWORD" | chpasswd; then
        echo "❌ Gagal set password user $USERNAME"
        cleanup_on_error
    fi
    
    echo "$USERNAME => $PASSWORD" >> "$PASSLOG"
    echo "✅ User '$USERNAME' berhasil dibuat"
    log_action "User $USERNAME created successfully"
    USER_CREATED=true
else
    echo "⚠️ User $USERNAME sudah ada."
    PASSWORD="(sudah ada)"
fi

# === BUAT FOLDER ===
echo "📁 Membuat direktori website..."
if ! mkdir -p "$DOC_ROOT"; then
    echo "❌ Gagal membuat direktori $DOC_ROOT"
    cleanup_on_error
fi

if ! chown -R "$USERNAME:$USERNAME" "$USER_HOME"; then
    echo "❌ Gagal set ownership untuk $USER_HOME"
    cleanup_on_error
fi

chmod 755 "$USER_HOME"
chmod 755 "$DOC_ROOT"
echo "✅ Direktori website berhasil dibuat"

# === Tambah index.php default dengan Tailwind ===
echo "🌐 Membuat halaman default..."
cat > "$DOC_ROOT/index.php" <<'EOF'
<?php
$php_version = phpversion();
$domain = $_SERVER['HTTP_HOST'] ?? 'Unknown';
$user = get_current_user();
$root = __DIR__;
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Website Aktif - <?php echo htmlspecialchars($domain); ?></title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center min-h-screen">
  <div class="bg-white p-10 rounded-2xl shadow-xl max-w-xl text-center">
    <h1 class="text-3xl font-bold text-gray-800 mb-4">🚀 Website Aktif</h1>
    <p class="text-gray-600 mb-6">Website ini berhasil dibuat dan siap digunakan.</p>

    <div class="text-left space-y-3 bg-gray-50 p-5 rounded-lg border">
      <p><span class="font-semibold text-gray-700">🌐 Domain:</span> <?php echo htmlspecialchars($domain); ?></p>
      <p><span class="font-semibold text-gray-700">🧑 User Linux:</span> <?php echo htmlspecialchars($user); ?></p>
      <p><span class="font-semibold text-gray-700">📁 Direktori:</span> <?php echo htmlspecialchars($root); ?></p>
      <p><span class="font-semibold text-gray-700">⚙️ PHP Version:</span> <?php echo htmlspecialchars($php_version); ?></p>
      <p><span class="font-semibold text-gray-700">⏰ Dibuat:</span> <?php echo date('Y-m-d H:i:s'); ?></p>
    </div>

    <div class="mt-6 p-4 bg-blue-50 rounded-lg border-l-4 border-blue-400">
      <p class="text-sm text-gray-600">
        <strong>📋 Panduan:</strong><br>
        1. Upload file website ke folder <code class="text-blue-600">public_html</code><br>
        2. Akses database MySQL dengan kredensial yang diberikan<br>
        3. Gunakan SSL/HTTPS untuk keamanan optimal
      </p>
    </div>
  </div>
</body>
</html>
EOF

if ! chown "$USERNAME:$USERNAME" "$DOC_ROOT/index.php"; then
    echo "❌ Gagal set ownership untuk index.php"
    cleanup_on_error
fi

echo "✅ Halaman default berhasil dibuat"

# === KONFIGURASI PHP-FPM POOL ===
echo "⚙️ Mengkonfigurasi PHP-FPM pool..."

# Backup konfigurasi PHP-FPM jika ada
if [ -f "$POOL_CONF" ]; then
    cp "$POOL_CONF" "$BACKUP_DIR/${USERNAME}_pool_$DATE.conf.backup"
fi

cat > "$POOL_CONF" <<EOF
[$USERNAME]
user = $USERNAME
group = $USERNAME
listen = $SOCK_FILE
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 200

chdir = /

; Security & Performance Settings
php_admin_value[memory_limit] = 256M
php_admin_value[upload_max_filesize] = 50M
php_admin_value[post_max_size] = 50M
php_admin_value[max_execution_time] = 120
php_admin_value[max_input_time] = 60
php_admin_value[open_basedir] = "$DOC_ROOT:/tmp"
php_admin_value[disable_functions] = "exec,passthru,shell_exec,system,proc_open,popen"
php_admin_value[date.timezone] = Asia/Jakarta
php_admin_value[log_errors] = On
php_admin_value[error_log] = /var/log/php/$USERNAME-fpm.log

; Session Security
php_admin_value[session.cookie_httponly] = On
php_admin_value[session.cookie_secure] = On
php_admin_value[session.use_strict_mode] = On
EOF

# Ensure PHP log directory exists and has proper permissions
mkdir -p /var/log/php 2>/dev/null || true
chmod 755 /var/log/php 2>/dev/null || true
chown root:adm /var/log/php 2>/dev/null || true

# Create the specific log file for this user
touch "/var/log/php/$USERNAME-fpm.log" 2>/dev/null || true
chmod 644 "/var/log/php/$USERNAME-fpm.log" 2>/dev/null || true
chown www-data:adm "/var/log/php/$USERNAME-fpm.log" 2>/dev/null || true

# Test konfigurasi PHP-FPM
if ! php-fpm$PHPVER -t &>/dev/null; then
    echo "❌ Konfigurasi PHP-FPM tidak valid"
    cleanup_on_error
fi

if ! systemctl restart php$PHPVER-fpm; then
    echo "❌ Gagal restart php$PHPVER-fpm"
    cleanup_on_error
fi

echo "✅ PHP-FPM pool berhasil dikonfigurasi"

# === KONFIGURASI VHOST APACHE ===
echo "🌐 Mengkonfigurasi Apache vhost..."

# Backup konfigurasi Apache jika ada
if [ -f "$VHOST_FILE" ]; then
    cp "$VHOST_FILE" "$BACKUP_DIR/${USERNAME}_vhost_$DATE.conf.backup"
fi

# Buat konfigurasi berdasarkan opsi SSL
if [ "$USE_SSL" = true ]; then
    echo "🔐 Mengkonfigurasi SSL..."
    
    # Setup SSL certificate berdasarkan type
    case $SSL_TYPE in
        "letsencrypt")
            if ! setup_letsencrypt "$DOMAIN"; then
                echo "⚠️ Let's Encrypt gagal, menggunakan self-signed"
                create_self_signed_cert "$DOMAIN"
            fi
            ;;
        "self-signed")
            create_self_signed_cert "$DOMAIN"
            ;;
    esac
    
    # Konfigurasi VHost dengan SSL
    cat > "$VHOST_FILE" <<EOF
# HTTP to HTTPS Redirect
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $DOC_ROOT
    
    # Security headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    
    # Redirect all HTTP to HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
</VirtualHost>

# HTTPS VirtualHost
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $DOC_ROOT

    # SSL Configuration
    SSLEngine on
    SSLCertificateFile $SSL_CERT_PATH
    SSLCertificateKeyFile $SSL_KEY_PATH
    
    # Modern SSL Configuration
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionTickets off
    
    # Security headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Directory configuration
    <Directory $DOC_ROOT>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Protect sensitive files
        <Files ~ "^\.">
            Require all denied
        </Files>
        
        <Files ~ "\.(log|ini|conf)$">
            Require all denied
        </Files>
    </Directory>

    # PHP-FPM Configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm-$USERNAME.sock|fcgi://localhost/"
    </FilesMatch>

    # Logging
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN.error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN.access.log combined
    
    # Log level for debugging (change to warn for production)
    LogLevel warn
</VirtualHost>
EOF

    echo "✅ Apache vhost dengan SSL berhasil dikonfigurasi"
    echo "   SSL Certificate: $SSL_CERT_PATH"
    echo "   SSL Private Key: $SSL_KEY_PATH"
    
else
    # Konfigurasi VHost tanpa SSL (HTTP only)
    cat > "$VHOST_FILE" <<EOF
# HTTP Only VirtualHost
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $DOC_ROOT
    
    # Security headers (tanpa HTTPS)
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Directory configuration
    <Directory $DOC_ROOT>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Protect sensitive files
        <Files ~ "^\.">
            Require all denied
        </Files>
        
        <Files ~ "\.(log|ini|conf)$">
            Require all denied
        </Files>
    </Directory>

    # PHP-FPM Configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php$PHPVER-fpm-$USERNAME.sock|fcgi://localhost/"
    </FilesMatch>

    # Logging
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN.error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN.access.log combined
    
    # Log level for debugging (change to warn for production)
    LogLevel warn
</VirtualHost>
EOF

    echo "✅ Apache vhost (HTTP only) berhasil dikonfigurasi"
    echo "⚠️ Website tidak menggunakan SSL/HTTPS"
fi

# Test konfigurasi Apache
if ! apache2ctl configtest; then
    echo "❌ Konfigurasi Apache tidak valid"
    cleanup_on_error
fi

if ! a2ensite "$DOMAIN.conf"; then
    echo "❌ Gagal mengaktifkan site $DOMAIN"
    cleanup_on_error
fi

# Enable required modules
a2enmod proxy_fcgi setenvif rewrite headers ssl

if ! systemctl reload apache2; then
    echo "❌ Gagal reload Apache"
    cleanup_on_error
fi

echo "✅ Apache vhost berhasil dikonfigurasi"

# === BUAT DATABASE & USER MYSQL ===
echo "🗄️ Membuat database MySQL..."

# Test koneksi MySQL dulu
if ! mysql -uroot -e "SELECT 1;" &>/dev/null; then
    echo "❌ Tidak dapat terhubung ke MySQL sebagai root"
    echo "   Pastikan MySQL berjalan dan root access tersedia"
    echo "   Test dengan: mysql -uroot -p"
    cleanup_on_error
fi

MYSQL_PASSWORD=$(openssl rand -base64 16)

# Validasi nama database dan user (untuk keamanan)
if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "❌ Nama database tidak valid: $DB_NAME"
    echo "   Hanya boleh mengandung huruf, angka, dan underscore"
    cleanup_on_error
fi

if [[ ! "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "❌ Nama user database tidak valid: $DB_USER"
    echo "   Hanya boleh mengandung huruf, angka, dan underscore"
    cleanup_on_error
fi

echo "📊 Info Database:"
echo "   Database Name: $DB_NAME"
echo "   Database User: $DB_USER"
echo "   Password: [Generated securely]"

# Cek apakah database sudah ada
echo "🔍 Memeriksa existing database..."
DB_EXISTS=$(mysql -uroot -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | grep "$DB_NAME" || true)

if [ -z "$DB_EXISTS" ]; then
    echo "📝 Membuat database dan user baru..."
    
    # Buat database
    echo "   Creating database: $DB_NAME"
    if ! mysql -uroot -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null; then
        echo "❌ Gagal membuat database MySQL: $DB_NAME"
        echo "   Error details:"
        mysql -uroot -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1 | head -5
        cleanup_on_error
    fi
    echo "   ✅ Database created successfully"
    
    # Cek apakah user sudah ada
    USER_EXISTS=$(mysql -uroot -e "SELECT User FROM mysql.user WHERE User='$DB_USER' AND Host='localhost';" 2>/dev/null | grep "$DB_USER" || true)
    
    if [ -n "$USER_EXISTS" ]; then
        echo "   ⚠️ User $DB_USER sudah ada, akan diupdate passwordnya"
        if ! mysql -uroot -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" 2>/dev/null; then
            echo "   ❌ Gagal update password user MySQL: $DB_USER"
            mysql -uroot -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" 2>&1 | head -5
            # Cleanup database yang baru dibuat
            mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
            cleanup_on_error
        fi
        echo "   ✅ User password updated"
    else
        # Buat user baru
        echo "   Creating user: $DB_USER"
        if ! mysql -uroot -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" 2>/dev/null; then
            echo "   ❌ Gagal membuat user MySQL: $DB_USER"
            echo "   Error details:"
            mysql -uroot -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" 2>&1 | head -5
            # Cleanup database yang baru dibuat
            mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
            cleanup_on_error
        fi
        echo "   ✅ User created successfully"
    fi
    
    # Berikan privileges
    echo "   Granting privileges..."
    if ! mysql -uroot -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';" 2>/dev/null; then
        echo "   ❌ Gagal memberikan privileges"
        echo "   Error details:"
        mysql -uroot -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';" 2>&1 | head -5
        # Cleanup
        mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
        mysql -uroot -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null
        cleanup_on_error
    fi
    echo "   ✅ Privileges granted"
    
    # Flush privileges
    if ! mysql -uroot -e "FLUSH PRIVILEGES;" 2>/dev/null; then
        echo "   ⚠️ Gagal flush privileges, tapi mungkin tidak critical"
    else
        echo "   ✅ Privileges flushed"
    fi
    
    # Log ke file
    echo "$DB_USER => $MYSQL_PASSWORD | DB: $DB_NAME | Created: $(date)" >> "$MYSQLLOG"
    echo "✅ Database dan user MySQL berhasil dibuat"
    log_action "Database $DB_NAME and user $DB_USER created successfully"
    DB_CREATED=true
    
else
    echo "⚠️ Database $DB_NAME sudah ada. Menggunakan database yang sudah ada."
    
    # Coba ambil password dari log jika ada
    EXISTING_PASS=$(grep "$DB_USER =>" "$MYSQLLOG" 2>/dev/null | tail -1 | cut -d'>' -f2 | cut -d'|' -f1 | xargs || true)
    
    if [ -n "$EXISTING_PASS" ]; then
        echo "   📋 Menggunakan password dari log existing"
        MYSQL_PASSWORD="$EXISTING_PASS"
    else
        echo "   🔄 Password existing tidak ditemukan di log"
        echo "   🔑 Akan menggunakan password baru dan update user"
        
        # Update password untuk user existing
        if mysql -uroot -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" 2>/dev/null; then
            echo "   ✅ Password user diupdate"
            echo "$DB_USER => $MYSQL_PASSWORD | DB: $DB_NAME | Updated: $(date)" >> "$MYSQLLOG"
        else
            echo "   ⚠️ Gagal update password, menggunakan password existing"
            echo "   💡 Anda mungkin perlu set password manual"
        fi
    fi
fi

# Test koneksi database dengan user yang dibuat
echo "🧪 Testing database connection..."
if mysql -u"$DB_USER" -p"$MYSQL_PASSWORD" -e "USE \`$DB_NAME\`; SELECT 'Connection successful' AS test;" 2>/dev/null | grep -q "Connection successful"; then
    echo "✅ Database connection test berhasil"
    log_action "Database connection test successful for $DB_USER@$DB_NAME"
else
    echo "❌ Database connection test gagal"
    echo "   Testing connection details:"
    echo "   User: $DB_USER"
    echo "   Database: $DB_NAME"
    echo "   Password length: ${#MYSQL_PASSWORD} characters"
    
    # Debug connection
    echo "   Attempting connection test with error output:"
    mysql -u"$DB_USER" -p"$MYSQL_PASSWORD" -e "USE \`$DB_NAME\`; SELECT 'Connection successful' AS test;" 2>&1 | head -3
    
    log_action "ERROR: Database connection test failed for $DB_USER@$DB_NAME"
    cleanup_on_error
fi

echo "✅ Database MySQL siap digunakan"

# === TEST WEBSITE ===
echo "🧪 Menguji website..."

# Test PHP-FPM socket
if [ -S "$SOCK_FILE" ]; then
    echo "✅ PHP-FPM socket aktif"
else
    echo "❌ PHP-FPM socket tidak aktif"
    cleanup_on_error
fi

# Test website accessibility
sleep 2  # Tunggu sebentar untuk Apache reload

if [ "$USE_SSL" = true ]; then
    echo "🔍 Testing HTTPS access..."
    if curl -s -k "https://$DOMAIN" -o /dev/null; then
        echo "✅ Website dapat diakses via HTTPS"
        
        # Test SSL certificate
        if [ "$SSL_TYPE" = "letsencrypt" ]; then
            echo "🔐 Verifying Let's Encrypt certificate..."
            if openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
                echo "✅ Let's Encrypt certificate valid"
            else
                echo "⚠️ Let's Encrypt certificate mungkin belum aktif sepenuhnya"
            fi
        fi
        
    else
        echo "❌ Website tidak dapat diakses via HTTPS"
        echo "   Checking HTTP fallback..."
        
        if curl -s "http://$DOMAIN" -o /dev/null; then
            echo "✅ Website dapat diakses via HTTP"
            echo "⚠️ HTTPS redirect mungkin tidak berfungsi"
        else
            echo "❌ Website tidak dapat diakses"
            echo "   Periksa konfigurasi DNS atau hosts file"
        fi
    fi
else
    echo "🔍 Testing HTTP access..."
    if curl -s "http://$DOMAIN" -o /dev/null; then
        echo "✅ Website dapat diakses via HTTP"
    else
        echo "❌ Website tidak dapat diakses"
        echo "   Periksa konfigurasi DNS atau hosts file"
    fi
fi

# Test PHP functionality
echo "🐘 Testing PHP functionality..."
if curl -s -k "https://$DOMAIN/index.php" 2>/dev/null | grep -q "Website Aktif" || curl -s "http://$DOMAIN/index.php" 2>/dev/null | grep -q "Website Aktif"; then
    echo "✅ PHP berfungsi dengan baik"
else
    echo "⚠️ PHP mungkin tidak berfungsi dengan baik"
fi

# Buat file info untuk troubleshooting
SSL_INFO=""
if [ "$USE_SSL" = true ]; then
    SSL_INFO="SSL Type: $SSL_TYPE
SSL Certificate: $SSL_CERT_PATH
SSL Private Key: $SSL_KEY_PATH
"
fi

cat > "$DOC_ROOT/info.txt" <<EOF
Website Info - $DOMAIN
========================
Created: $(date)
PHP Version: $PHPVER
Socket: $SOCK_FILE
Database: $DB_NAME
User: $DB_USER
Document Root: $DOC_ROOT
SSL Enabled: $USE_SSL
$SSL_INFO
Log Files:
- Apache Error: /var/log/apache2/$DOMAIN.error.log
- Apache Access: /var/log/apache2/$DOMAIN.access.log
- PHP-FPM: /var/log/php/$USERNAME-fpm.log

SSL Commands:
- Check certificate: openssl s_client -connect $DOMAIN:443 -servername $DOMAIN
- Renew Let's Encrypt: certbot renew --dry-run
- Check renewal timer: systemctl status certbot-renewal.timer
EOF

chown "$USERNAME:$USERNAME" "$DOC_ROOT/info.txt"
chmod 640 "$DOC_ROOT/info.txt"

log_action "Website $DOMAIN created successfully with PHP $PHPVER and SSL: $USE_SSL ($SSL_TYPE)"

# Disable trap karena sudah selesai
trap - ERR
# === RINGKASAN HASIL ===
echo ""
echo "🎉 Website $DOMAIN berhasil dibuat!"
echo "================================================"
echo "📁 Document Root : $DOC_ROOT"
echo "👤 Linux User    : $USERNAME"
echo "🔑 SSH Password  : $PASSWORD"
echo "🛠️  PHP Version   : $PHPVER"
echo "🔌 PHP Socket    : $SOCK_FILE"
echo "🌐 Apache VHost  : $VHOST_FILE"
echo "�️  Database Name : $DB_NAME"
echo "👤 Database User : $DB_USER"
echo "🔑 Database Pass : $MYSQL_PASSWORD"

# SSL Information
if [ "$USE_SSL" = true ]; then
    echo "🔒 SSL Status    : Enabled ($SSL_TYPE)"
    echo "📜 SSL Cert     : $SSL_CERT_PATH"
    echo "🔐 SSL Key      : $SSL_KEY_PATH"
    
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        echo "🔄 Auto-renewal : Enabled (setiap 12 jam)"
    elif [ "$SSL_TYPE" = "self-signed" ]; then
        echo "⚠️ Self-signed  : Valid untuk 365 hari"
    fi
else
    echo "🔒 SSL Status    : Disabled (HTTP only)"
fi
echo ""
echo "� File Log:"
echo "   SSH Passwords : $PASSLOG"
echo "   MySQL Info    : $MYSQLLOG"
echo "   Activity Log  : /var/log/website-management.log"
echo "   Config Backup : $BACKUP_DIR/"
echo ""
echo "🌍 Akses Website:"

if [ "$USE_SSL" = true ]; then
    echo "   HTTP  : http://$DOMAIN (redirect ke HTTPS)"
    echo "   HTTPS : https://$DOMAIN"
    echo "   Info  : https://$DOMAIN/info.txt"
else
    echo "   HTTP  : http://$DOMAIN"
    echo "   Info  : http://$DOMAIN/info.txt"
fi
echo ""
echo "💡 Tips:"
echo "   - Upload file ke: $DOC_ROOT/"
echo "   - Cek error log: tail -f /var/log/apache2/$DOMAIN.error.log"
echo "   - Test PHP: systemctl status php$PHPVER-fpm"
echo "   - Restart services: systemctl restart php$PHPVER-fpm apache2"

if [ "$USE_SSL" = true ]; then
    echo ""
    echo "🔒 SSL Management:"
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        echo "   - Cek certificate: certbot certificates"
        echo "   - Renew manual: certbot renew"
        echo "   - Test renewal: certbot renew --dry-run"
        echo "   - Check timer: systemctl status certbot-renewal.timer"
    elif [ "$SSL_TYPE" = "self-signed" ]; then
        echo "   - Certificate valid: 365 hari"
        echo "   - Generate baru: openssl req -new -x509 -key $SSL_KEY_PATH -out $SSL_CERT_PATH -days 365"
    fi
fi

echo ""
echo "🚨 Troubleshooting:"
echo "   - Check Apache config: apache2ctl configtest"
echo "   - Check PHP-FPM: systemctl status php$PHPVER-fpm"
echo "   - Check website: curl -I http://$DOMAIN"

if [ "$USE_SSL" = true ]; then
    echo "   - Check SSL: openssl s_client -connect $DOMAIN:443 -servername $DOMAIN"
fi

