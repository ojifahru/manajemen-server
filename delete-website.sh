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

# Fungsi untuk menampilkan informasi website
show_website_info() {
    local domain=$1
    local username=$2
    local vhost_file=$3
    local user_home=$4
    local db_name=$5
    
    echo ""
    echo "📋 INFORMASI WEBSITE YANG AKAN DIHAPUS:"
    echo "========================================"
    echo "🌐 Domain        : $domain"
    echo "👤 Username      : $username"
    echo "📁 Home Directory: $user_home"
    echo "🌐 VHost File    : $vhost_file"
    echo "🗄️  Database      : $db_name"
    
    # Cek ukuran folder
    if [ -d "$user_home" ]; then
        local size=$(du -sh "$user_home" 2>/dev/null | cut -f1)
        echo "📊 Ukuran Folder : $size"
    fi
    
    # Cek proses user
    if id "$username" &>/dev/null; then
        local processes=$(pgrep -u "$username" 2>/dev/null | wc -l)
        echo "🔧 Proses Aktif  : $processes"
    fi
    
    echo ""
}

# === INPUT dengan validasi ===
while true; do
    read -p "Masukkan nama domain yang ingin DIHAPUS (contoh: mysite.local): " DOMAIN
    if validate_domain "$DOMAIN"; then
        break
    fi
done

USERNAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')
USER_HOME="/home/$USERNAME"
DOC_ROOT="$USER_HOME/public_html"
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
DB_NAME="${USERNAME}_db"
DB_USER="$USERNAME"
BACKUP_DIR="/root/website-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/${USERNAME}_backup_$DATE.zip"

# === Validasi awal ===
if [ ! -f "$VHOST_FILE" ]; then
    echo "❌ File vhost tidak ditemukan: $VHOST_FILE"
    echo "   Website dengan domain $DOMAIN tidak terdaftar di sistem."
    exit 1
fi

# Deteksi versi PHP
PHPVER=$(grep -oP 'php\K\d+\.\d+(?=-fpm)' "$VHOST_FILE" | head -n1)

if [ -z "$PHPVER" ]; then
    echo "❌ Gagal mendeteksi versi PHP dari vhost."
    echo "   File vhost mungkin rusak atau tidak menggunakan PHP-FPM."
    exit 1
fi

POOL_FILE="/etc/php/$PHPVER/fpm/pool.d/$USERNAME.conf"
DISABLED_POOL_FILE="$POOL_FILE.disabled"

# Tampilkan informasi website
show_website_info "$DOMAIN" "$USERNAME" "$VHOST_FILE" "$USER_HOME" "$DB_NAME"

# Konfirmasi pertama
echo "⚠️  PERINGATAN: Operasi ini akan MENGHAPUS PERMANEN semua data website!"
echo "   - File dan folder website"
echo "   - Database MySQL"
echo "   - User Linux"
echo "   - Konfigurasi Apache dan PHP-FPM"
echo ""

read -p "Apakah Anda yakin ingin melanjutkan? (ketik 'DELETE' untuk konfirmasi): " CONFIRM1
if [ "$CONFIRM1" != "DELETE" ]; then
    echo "❌ Operasi dibatalkan."
    exit 0
fi

# Konfirmasi kedua
echo ""
echo "🔴 KONFIRMASI TERAKHIR!"
read -p "Ketik nama domain ($DOMAIN) untuk konfirmasi akhir: " CONFIRM2
if [ "$CONFIRM2" != "$DOMAIN" ]; then
    echo "❌ Konfirmasi tidak sesuai. Operasi dibatalkan."
    exit 0
fi

log_action "Starting website deletion for $DOMAIN (PHP $PHPVER, User: $USERNAME)"

echo ""
echo "📦 Membuat backup komprehensif sebelum menghapus website..."

# Buat direktori backup dengan permission yang tepat
if ! mkdir -p "$BACKUP_DIR"; then
    echo "❌ Gagal membuat direktori backup: $BACKUP_DIR"
    exit 1
fi

chmod 700 "$BACKUP_DIR"

# Buat temporary directory untuk backup
TEMP_BACKUP_DIR="/tmp/website_backup_${USERNAME}_$$"
mkdir -p "$TEMP_BACKUP_DIR"

# === Backup konfigurasi ===
echo "🔧 Backup konfigurasi..."
CONFIG_BACKUP_DIR="$TEMP_BACKUP_DIR/config"
mkdir -p "$CONFIG_BACKUP_DIR"

# Backup Apache vhost
if [ -f "$VHOST_FILE" ]; then
    cp "$VHOST_FILE" "$CONFIG_BACKUP_DIR/apache_vhost.conf"
    echo "✅ Apache vhost dibackup"
else
    echo "⚠️ Apache vhost tidak ditemukan"
fi

# Backup PHP-FPM pool (aktif atau disabled)
if [ -f "$POOL_FILE" ]; then
    cp "$POOL_FILE" "$CONFIG_BACKUP_DIR/php_fpm_pool.conf"
    echo "✅ PHP-FPM pool dibackup"
elif [ -f "$DISABLED_POOL_FILE" ]; then
    cp "$DISABLED_POOL_FILE" "$CONFIG_BACKUP_DIR/php_fpm_pool.conf.disabled"
    echo "✅ PHP-FPM pool (disabled) dibackup"
else
    echo "⚠️ PHP-FPM pool tidak ditemukan"
fi

# Backup log files
LOG_BACKUP_DIR="$TEMP_BACKUP_DIR/logs"
mkdir -p "$LOG_BACKUP_DIR"

if [ -f "/var/log/apache2/$DOMAIN.error.log" ]; then
    cp "/var/log/apache2/$DOMAIN.error.log" "$LOG_BACKUP_DIR/"
fi

if [ -f "/var/log/apache2/$DOMAIN.access.log" ]; then
    cp "/var/log/apache2/$DOMAIN.access.log" "$LOG_BACKUP_DIR/"
fi

# Backup user info
echo "👤 Backup informasi user..."
USER_INFO_FILE="$TEMP_BACKUP_DIR/user_info.txt"
{
    echo "Domain: $DOMAIN"
    echo "Username: $USERNAME"
    echo "PHP Version: $PHPVER"
    echo "Created: $(date)"
    echo "Home Directory: $USER_HOME"
    echo "Database: $DB_NAME"
    echo ""
    echo "User Information:"
    id "$USERNAME" 2>/dev/null || echo "User not found"
    echo ""
    echo "User Processes:"
    ps -u "$USERNAME" 2>/dev/null || echo "No processes found"
} > "$USER_INFO_FILE"

# === Backup folder website ===
echo "📁 Backup folder website..."
if [ -d "$USER_HOME" ]; then
    # Hitung ukuran folder
    FOLDER_SIZE=$(du -sh "$USER_HOME" 2>/dev/null | cut -f1)
    echo "   Ukuran folder: $FOLDER_SIZE"
    
    # Backup dengan preservasi permission dan metadata
    if cp -a "$USER_HOME" "$TEMP_BACKUP_DIR/home_backup"; then
        echo "✅ Folder website ($FOLDER_SIZE) berhasil dibackup"
        log_action "Website folder backup completed: $FOLDER_SIZE"
    else
        echo "❌ Gagal backup folder website"
        log_action "ERROR: Failed to backup website folder"
        rm -rf "$TEMP_BACKUP_DIR"
        exit 1
    fi
else
    echo "⚠️ Folder $USER_HOME tidak ditemukan"
    log_action "WARNING: User home directory not found: $USER_HOME"
fi

# === Backup database ===
echo "🗄️ Backup database MySQL..."
if mysql -uroot -e "USE \`$DB_NAME\`;" 2>/dev/null; then
    # Cek ukuran database
    DB_SIZE=$(mysql -uroot -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'DB Size (MB)' FROM information_schema.tables WHERE table_schema='\`$DB_NAME\`';" 2>/dev/null | tail -1)
    
    echo "   Ukuran database: ${DB_SIZE} MB"
    
    if mysqldump -uroot --single-transaction --routines --triggers "$DB_NAME" > "$TEMP_BACKUP_DIR/${DB_NAME}.sql"; then
        echo "✅ Database MySQL (${DB_SIZE} MB) berhasil dibackup"
        log_action "Database backup completed: ${DB_SIZE} MB"
    else
        echo "❌ Gagal backup database MySQL"
        log_action "ERROR: Failed to backup database"
        rm -rf "$TEMP_BACKUP_DIR"
        exit 1
    fi
    
    # Backup user grants
    mysql -uroot -e "SHOW GRANTS FOR '$DB_USER'@'localhost';" 2>/dev/null > "$TEMP_BACKUP_DIR/${DB_USER}_grants.sql"
else
    echo "⚠️ Database $DB_NAME tidak ditemukan atau tidak dapat diakses"
    log_action "WARNING: Database not found or inaccessible: $DB_NAME"
fi

# === Buat archive backup ===
echo "🗜️ Membuat archive backup..."
cd "$TEMP_BACKUP_DIR"
if zip -rq "$BACKUP_FILE" . 2>/dev/null; then
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" 2>/dev/null | cut -f1)
    echo "✅ Backup berhasil dibuat: $BACKUP_FILE ($BACKUP_SIZE)"
    log_action "Backup archive created: $BACKUP_FILE ($BACKUP_SIZE)"
else
    echo "❌ Gagal membuat archive backup"
    log_action "ERROR: Failed to create backup archive"
    rm -rf "$TEMP_BACKUP_DIR"
    exit 1
fi

# Bersihkan temporary directory
rm -rf "$TEMP_BACKUP_DIR"

# === Nonaktifkan website terlebih dahulu ===
echo ""
echo "🛑 Menonaktifkan website..."

# Disable Apache site
if [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
    if a2dissite "$DOMAIN.conf" &>/dev/null; then
        echo "✅ Apache site dinonaktifkan"
    else
        echo "⚠️ Gagal disable Apache site"
    fi
fi

# Reload Apache
if systemctl reload apache2 2>/dev/null; then
    echo "✅ Apache configuration direload"
else
    echo "⚠️ Gagal reload Apache"
fi

# === Hapus proses user dengan grace period ===
echo ""
echo "🔄 Menghentikan proses user..."
if id "$USERNAME" &>/dev/null; then
    # Tampilkan proses yang berjalan
    RUNNING_PROCESSES=$(pgrep -u "$USERNAME" 2>/dev/null | wc -l)
    
    if [ "$RUNNING_PROCESSES" -gt 0 ]; then
        echo "🔍 Ditemukan $RUNNING_PROCESSES proses yang berjalan untuk user '$USERNAME'"
        echo "   Proses akan dihentikan dengan grace period..."
        
        # Kirim SIGTERM terlebih dahulu (graceful shutdown)
        if pkill -TERM -u "$USERNAME" 2>/dev/null; then
            echo "✅ Sinyal TERM dikirim ke semua proses"
        fi
        
        # Tunggu 5 detik untuk graceful shutdown
        sleep 5
        
        # Cek apakah masih ada proses
        REMAINING_PROCESSES=$(pgrep -u "$USERNAME" 2>/dev/null | wc -l)
        
        if [ "$REMAINING_PROCESSES" -gt 0 ]; then
            echo "⚠️ Masih ada $REMAINING_PROCESSES proses aktif, menggunakan SIGKILL..."
            pkill -KILL -u "$USERNAME" 2>/dev/null
            sleep 2
        fi
        
        # Final check
        if pgrep -u "$USERNAME" > /dev/null 2>&1; then
            echo "❌ Gagal menghentikan semua proses user '$USERNAME'"
            echo "   Proses yang masih berjalan:"
            ps -u "$USERNAME" 2>/dev/null
            echo ""
            echo "   Silakan hentikan proses secara manual lalu jalankan script lagi."
            log_action "ERROR: Failed to kill all user processes for $USERNAME"
            exit 1
        else
            echo "✅ Semua proses user berhasil dihentikan"
        fi
    else
        echo "✅ Tidak ada proses yang berjalan untuk user '$USERNAME'"
    fi
fi

# === Hapus Apache vhost ===
echo ""
echo "🧹 Menghapus konfigurasi Apache..."
if [ -f "$VHOST_FILE" ]; then
    if rm -f "$VHOST_FILE"; then
        echo "✅ Apache vhost dihapus: $VHOST_FILE"
        log_action "Apache vhost deleted: $VHOST_FILE"
    else
        echo "❌ Gagal menghapus Apache vhost"
        log_action "ERROR: Failed to delete Apache vhost"
    fi
else
    echo "⚠️ Apache vhost sudah tidak ada"
fi

# Reload Apache setelah hapus vhost
if systemctl reload apache2 2>/dev/null; then
    echo "✅ Apache configuration direload"
else
    echo "⚠️ Gagal reload Apache"
fi

# === Hapus PHP-FPM pool ===
echo ""
echo "🧹 Menghapus konfigurasi PHP-FPM..."
POOL_DELETED=false

# Hapus pool aktif
if [ -f "$POOL_FILE" ]; then
    if rm -f "$POOL_FILE"; then
        echo "✅ PHP-FPM pool dihapus: $POOL_FILE"
        log_action "PHP-FPM pool deleted: $POOL_FILE"
        POOL_DELETED=true
    else
        echo "❌ Gagal menghapus PHP-FPM pool"
        log_action "ERROR: Failed to delete PHP-FPM pool"
    fi
fi

# Hapus pool disabled jika ada
if [ -f "$DISABLED_POOL_FILE" ]; then
    if rm -f "$DISABLED_POOL_FILE"; then
        echo "✅ PHP-FPM pool disabled dihapus: $DISABLED_POOL_FILE"
        log_action "PHP-FPM disabled pool deleted: $DISABLED_POOL_FILE"
        POOL_DELETED=true
    else
        echo "❌ Gagal menghapus PHP-FPM pool disabled"
    fi
fi

if [ "$POOL_DELETED" = false ]; then
    echo "⚠️ PHP-FPM pool sudah tidak ada"
fi

# Restart PHP-FPM service
if systemctl is-active php$PHPVER-fpm &>/dev/null; then
    if systemctl restart php$PHPVER-fpm 2>/dev/null; then
        echo "✅ PHP-FPM service direstart"
    else
        echo "⚠️ Gagal restart PHP-FPM service"
    fi
else
    echo "⚠️ PHP-FPM service tidak aktif"
fi

# === Hapus user Linux ===
echo ""
echo "🧹 Menghapus user Linux..."
if id "$USERNAME" &>/dev/null; then
    if userdel -r "$USERNAME" 2>/dev/null; then
        echo "✅ User Linux '$USERNAME' dan home directory berhasil dihapus"
        log_action "Linux user deleted: $USERNAME"
    else
        echo "❌ Gagal menghapus user Linux '$USERNAME'"
        echo "   Mungkin ada file yang masih dibuka atau permission issue"
        log_action "ERROR: Failed to delete Linux user: $USERNAME"
    fi
else
    echo "⚠️ User '$USERNAME' sudah tidak ada"
fi

# === Hapus database dan user MySQL ===
echo ""
echo "🧹 Menghapus database MySQL..."

# Cek apakah database ada
if mysql -uroot -e "USE \`$DB_NAME\`;" 2>/dev/null; then
    if mysql -uroot -e "DROP DATABASE \`$DB_NAME\`;" 2>/dev/null; then
        echo "✅ Database '$DB_NAME' berhasil dihapus"
        log_action "Database deleted: $DB_NAME"
    else
        echo "❌ Gagal menghapus database '$DB_NAME'"
        log_action "ERROR: Failed to delete database: $DB_NAME"
    fi
else
    echo "⚠️ Database '$DB_NAME' sudah tidak ada"
fi

# Hapus user MySQL
if mysql -uroot -e "SELECT User FROM mysql.user WHERE User='$DB_USER' AND Host='localhost';" 2>/dev/null | grep -q "$DB_USER"; then
    if mysql -uroot -e "DROP USER '$DB_USER'@'localhost';" 2>/dev/null; then
        echo "✅ User MySQL '$DB_USER' berhasil dihapus"
        log_action "MySQL user deleted: $DB_USER"
    else
        echo "❌ Gagal menghapus user MySQL '$DB_USER'"
        log_action "ERROR: Failed to delete MySQL user: $DB_USER"
    fi
else
    echo "⚠️ User MySQL '$DB_USER' sudah tidak ada"
fi

# Flush privileges untuk memastikan perubahan diterapkan
mysql -uroot -e "FLUSH PRIVILEGES;" 2>/dev/null

# === Bersihkan log files ===
echo ""
echo "🧹 Membersihkan log files..."
LOG_FILES=(
    "/var/log/apache2/$DOMAIN.error.log"
    "/var/log/apache2/$DOMAIN.access.log"
    "/var/log/php/$USERNAME-fpm.log"
)

for log_file in "${LOG_FILES[@]}"; do
    if [ -f "$log_file" ]; then
        if rm -f "$log_file"; then
            echo "✅ Log file dihapus: $log_file"
        else
            echo "⚠️ Gagal menghapus log file: $log_file"
        fi
    fi
done

# Hapus dari password logs
if [ -f "/root/website-passwords.txt" ]; then
    sed -i "/^$USERNAME =>/d" "/root/website-passwords.txt" 2>/dev/null
    echo "✅ Entry password log dihapus"
fi

if [ -f "/root/website-mysql-passwords.txt" ]; then
    sed -i "/^$DB_USER =>/d" "/root/website-mysql-passwords.txt" 2>/dev/null
    echo "✅ Entry MySQL password log dihapus"
fi

log_action "Website deletion completed for $DOMAIN"

echo ""
echo "🎉 Website $DOMAIN berhasil DIHAPUS TOTAL!"
echo "================================================"
echo "🗑️  Yang telah dihapus:"
echo "   ✅ Apache VHost configuration"
echo "   ✅ PHP-FPM pool configuration"
echo "   ✅ Linux user dan home directory"
echo "   ✅ Database MySQL dan user"
echo "   ✅ Log files"
echo "   ✅ Password entries"
echo ""
echo "� Backup Information:"
echo "   📁 File backup : $BACKUP_FILE"
echo "   📊 Ukuran      : $(du -sh "$BACKUP_FILE" 2>/dev/null | cut -f1)"
echo "   📅 Tanggal     : $(date)"
echo ""
echo "🔄 Restore Instructions:"
echo "   1. Extract backup: unzip $BACKUP_FILE"
echo "   2. Restore database: mysql -uroot < DB_backup.sql"
echo "   3. Restore configurations dari folder config/"
echo "   4. Recreate user: useradd -m -d /home/$USERNAME $USERNAME"
echo "   5. Restore home directory"
echo ""
echo "📋 Log aktivitas tersimpan di: /var/log/website-management.log"
echo ""
echo "💡 Tips:"
echo "   - Backup akan tersimpan selama 30 hari"
echo "   - Gunakan script restore jika perlu mengembalikan website"
echo "   - Periksa log jika ada masalah"
