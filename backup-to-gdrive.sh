#!/bin/bash

# Script untuk backup website harian ke Google Drive
# Author: Server Management Script
# Version: 1.0
# Description: Backup files dan database website ke Google Drive secara otomatis

# Fungsi untuk menampilkan bantuan
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help          Tampilkan bantuan ini
    -u, --user          Backup website user tertentu saja
    -d, --domain        Backup domain tertentu saja
    -f, --files-only    Backup files saja (tanpa database)
    -b, --db-only       Backup database saja (tanpa files)
    -c, --compress      Gunakan kompresi maksimal
    -t, --test          Test mode (tidak upload ke Google Drive)
    --setup             Setup Google Drive credentials
    --setup-mysql       Setup MySQL credentials
    --check-mysql       Cek status MySQL user dan permissions
    --cron              Tampilkan contoh cron job

Examples:
    $0                     # Backup semua website
    $0 -u johndoe         # Backup website user johndoe
    $0 -d example.com     # Backup domain example.com
    $0 -f                 # Backup files saja
    $0 --setup            # Setup Google Drive
    $0 --setup-mysql      # Setup MySQL credentials
    $0 --check-mysql      # Cek MySQL status
    $0 --cron             # Tampilkan cron setup

EOF
}

# Fungsi untuk deteksi warna terminal
supports_color() {
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && command -v tput >/dev/null 2>&1
}

# Setup warna jika terminal mendukung
if supports_color; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" RESET=""
fi

# Konfigurasi default
BACKUP_DIR="/tmp/website-backups"
GDRIVE_DIR="/Website-Backups"
MYSQL_USER="root"
MYSQL_PASSWORD=""
MYSQL_CONFIG_FILE="/root/.my.cnf"
VHOST_DIR="/etc/apache2/sites-available"
RETENTION_DAYS=30
COMPRESS_LEVEL=6

# Load konfigurasi dari file jika ada
CONFIG_FILE="/etc/backup-gdrive.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Fungsi untuk setup MySQL credentials
setup_mysql_credentials() {
    echo "${CYAN}🔐 Setting up MySQL credentials...${RESET}"
    
    # Cek apakah ada .my.cnf file
    if [[ -f "$MYSQL_CONFIG_FILE" ]]; then
        echo "${GREEN}✅ MySQL config file found: $MYSQL_CONFIG_FILE${RESET}"
        return 0
    fi
    
    echo "${YELLOW}Pilih opsi setup MySQL:${RESET}"
    echo "1. Gunakan root tanpa password (tidak aman untuk production)"
    echo "2. Gunakan root dengan password"
    echo "3. Buat user backup baru (direkomendasikan)"
    echo ""
    read -p "Pilih opsi (1-3): " mysql_option
    
    case $mysql_option in
        1)
            # Root tanpa password
            echo "${YELLOW}⚠️  Menggunakan root tanpa password...${RESET}"
            
            # Test connection
            if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
                echo "${GREEN}✅ MySQL connection berhasil${RESET}"
                
                # Buat .my.cnf file
                cat > "$MYSQL_CONFIG_FILE" << EOF
[client]
user=root

[mysql]
user=root

[mysqldump]
user=root
EOF
                chmod 600 "$MYSQL_CONFIG_FILE"
                echo "${GREEN}✅ MySQL credentials disimpan ke: $MYSQL_CONFIG_FILE${RESET}"
                return 0
            else
                echo "${RED}❌ MySQL connection gagal${RESET}"
                return 1
            fi
            ;;
        2)
            # Root dengan password
            echo "${CYAN}Setup root dengan password...${RESET}"
            read -s -p "MySQL root password: " mysql_password
            echo
            
            # Test connection
            if mysql -u root -p"$mysql_password" -e "SELECT 1;" >/dev/null 2>&1; then
                echo "${GREEN}✅ MySQL connection berhasil${RESET}"
                
                # Buat .my.cnf file
                cat > "$MYSQL_CONFIG_FILE" << EOF
[client]
user=root
password=$mysql_password

[mysql]
user=root
password=$mysql_password

[mysqldump]
user=root
password=$mysql_password
EOF
                chmod 600 "$MYSQL_CONFIG_FILE"
                echo "${GREEN}✅ MySQL credentials disimpan ke: $MYSQL_CONFIG_FILE${RESET}"
                return 0
            else
                echo "${RED}❌ MySQL connection gagal${RESET}"
                return 1
            fi
            ;;
        3)
            # Buat user backup baru
            echo "${CYAN}Membuat user backup baru...${RESET}"
            
            # Input untuk user baru
            read -p "Username untuk backup (default: backupuser): " backup_user
            backup_user=${backup_user:-backupuser}
            
            read -s -p "Password untuk user backup: " backup_password
            echo
            
            # Test root connection dulu
            echo "${CYAN}Testing root connection untuk membuat user...${RESET}"
            if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
                echo "${GREEN}✅ Root connection berhasil${RESET}"
                
                # Buat user backup
                echo "${CYAN}Membuat user backup: $backup_user${RESET}"
                
                mysql -u root << EOF
-- Hapus user jika sudah ada
DROP USER IF EXISTS '$backup_user'@'localhost';

-- Buat user baru
CREATE USER '$backup_user'@'localhost' IDENTIFIED BY '$backup_password';

-- Grant privileges untuk backup
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO '$backup_user'@'localhost';
GRANT REPLICATION CLIENT ON *.* TO '$backup_user'@'localhost';
GRANT SHOW DATABASES ON *.* TO '$backup_user'@'localhost';

-- Flush privileges
FLUSH PRIVILEGES;
EOF
                
                if [[ $? -eq 0 ]]; then
                    echo "${GREEN}✅ User backup berhasil dibuat${RESET}"
                    
                    # Test connection dengan user baru
                    if mysql -u"$backup_user" -p"$backup_password" -e "SELECT 1;" >/dev/null 2>&1; then
                        echo "${GREEN}✅ User backup connection berhasil${RESET}"
                        
                        # Buat .my.cnf file
                        cat > "$MYSQL_CONFIG_FILE" << EOF
[client]
user=$backup_user
password=$backup_password

[mysql]
user=$backup_user
password=$backup_password

[mysqldump]
user=$backup_user
password=$backup_password
EOF
                        chmod 600 "$MYSQL_CONFIG_FILE"
                        echo "${GREEN}✅ MySQL credentials disimpan ke: $MYSQL_CONFIG_FILE${RESET}"
                        
                        # Update variables
                        MYSQL_USER="$backup_user"
                        MYSQL_PASSWORD="$backup_password"
                        
                        return 0
                    else
                        echo "${RED}❌ User backup connection gagal${RESET}"
                        return 1
                    fi
                else
                    echo "${RED}❌ Gagal membuat user backup${RESET}"
                    return 1
                fi
            else
                echo "${RED}❌ Root connection gagal. Pastikan MySQL root accessible${RESET}"
                return 1
            fi
            ;;
        *)
            echo "${RED}❌ Pilihan tidak valid${RESET}"
            return 1
            ;;
    esac
}

# Fungsi untuk cek status MySQL
check_mysql_status() {
    echo "${BOLD}🔍 MySQL Status Check${RESET}"
    echo "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
    
    # Cek apakah MySQL running
    if ! command -v mysql >/dev/null 2>&1; then
        echo "${RED}❌ MySQL client tidak ditemukan${RESET}"
        return 1
    fi
    
    # Cek config file
    if [[ -f "$MYSQL_CONFIG_FILE" ]]; then
        echo "${GREEN}✅ MySQL config file: $MYSQL_CONFIG_FILE${RESET}"
        
        # Ambil username dari config
        local config_user=$(grep "^user=" "$MYSQL_CONFIG_FILE" | head -n1 | cut -d'=' -f2)
        echo "${CYAN}Current user: $config_user${RESET}"
        
        # Test connection
        if mysql --defaults-file="$MYSQL_CONFIG_FILE" -e "SELECT 1;" >/dev/null 2>&1; then
            echo "${GREEN}✅ MySQL connection berhasil${RESET}"
            
            # Tampilkan user info
            echo ""
            echo "${BOLD}📊 User Information:${RESET}"
            mysql --defaults-file="$MYSQL_CONFIG_FILE" -e "
                SELECT 
                    User as 'Username',
                    Host as 'Host',
                    authentication_string != '' as 'Has_Password',
                    account_locked as 'Locked',
                    password_expired as 'Expired'
                FROM mysql.user 
                WHERE User = '$config_user';
            " 2>/dev/null || echo "${YELLOW}⚠️  Tidak bisa mengakses mysql.user table${RESET}"
            
            # Tampilkan permissions
            echo ""
            echo "${BOLD}🔐 User Privileges:${RESET}"
            mysql --defaults-file="$MYSQL_CONFIG_FILE" -e "SHOW GRANTS FOR CURRENT_USER();" 2>/dev/null | while read -r line; do
                echo "${CYAN}  $line${RESET}"
            done
            
            # Test database access
            echo ""
            echo "${BOLD}🗄️  Database Access Test:${RESET}"
            local db_count=$(mysql --defaults-file="$MYSQL_CONFIG_FILE" -e "SHOW DATABASES;" 2>/dev/null | wc -l)
            if [[ $db_count -gt 1 ]]; then
                echo "${GREEN}✅ Dapat mengakses $((db_count-1)) databases${RESET}"
                
                # Test mysqldump
                local test_db=$(mysql --defaults-file="$MYSQL_CONFIG_FILE" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys" | head -n1)
                if [[ -n "$test_db" ]]; then
                    echo "${CYAN}Testing mysqldump dengan database: $test_db${RESET}"
                    if mysqldump --defaults-file="$MYSQL_CONFIG_FILE" --single-transaction --no-data "$test_db" >/dev/null 2>&1; then
                        echo "${GREEN}✅ mysqldump test berhasil${RESET}"
                    else
                        echo "${RED}❌ mysqldump test gagal${RESET}"
                        echo "${YELLOW}User mungkin tidak memiliki permission LOCK TABLES atau SHOW VIEW${RESET}"
                    fi
                fi
            else
                echo "${RED}❌ Tidak dapat mengakses database${RESET}"
            fi
            
        else
            echo "${RED}❌ MySQL connection gagal${RESET}"
            echo "${YELLOW}Jalankan: $0 --setup-mysql untuk mengatur ulang${RESET}"
            return 1
        fi
    else
        echo "${YELLOW}⚠️  MySQL config file tidak ditemukan: $MYSQL_CONFIG_FILE${RESET}"
        echo "${CYAN}Jalankan: $0 --setup-mysql untuk setup${RESET}"
        return 1
    fi
    
    echo ""
    echo "${CYAN}💡 Tips Keamanan:${RESET}"
    echo "• Gunakan user khusus backup, bukan root"
    echo "• Berikan hanya permission minimal yang diperlukan"
    echo "• Gunakan password yang kuat"
    echo "• Monitor log backup secara berkala"
}

# Parse arguments
FILTER_USER=""
FILTER_DOMAIN=""
FILES_ONLY=false
DB_ONLY=false
COMPRESS_MAX=false
TEST_MODE=false
SETUP_MODE=false
SETUP_MYSQL_MODE=false
CHECK_MYSQL_MODE=false
SHOW_CRON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--user)
            FILTER_USER="$2"
            shift 2
            ;;
        -d|--domain)
            FILTER_DOMAIN="$2"
            shift 2
            ;;
        -f|--files-only)
            FILES_ONLY=true
            shift
            ;;
        -b|--db-only)
            DB_ONLY=true
            shift
            ;;
        -c|--compress)
            COMPRESS_MAX=true
            COMPRESS_LEVEL=9
            shift
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        --setup)
            SETUP_MODE=true
            shift
            ;;
        --setup-mysql)
            SETUP_MYSQL_MODE=true
            shift
            ;;
        --check-mysql)
            CHECK_MYSQL_MODE=true
            shift
            ;;
        --cron)
            SHOW_CRON=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fungsi untuk setup Google Drive
setup_gdrive() {
    echo "${BOLD}🔧 Setup Google Drive Integration${RESET}"
    echo "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
    
    # Cek apakah rclone sudah terinstall
    if ! command -v rclone >/dev/null 2>&1; then
        echo "${YELLOW}⚠️  rclone tidak ditemukan. Menginstall rclone...${RESET}"
        
        # Install rclone
        curl https://rclone.org/install.sh | bash
        
        if ! command -v rclone >/dev/null 2>&1; then
            echo "${RED}❌ Gagal menginstall rclone${RESET}"
            exit 1
        fi
    fi
    
    echo "${GREEN}✅ rclone ditemukan${RESET}"
    
    # Setup Google Drive remote
    echo ""
    echo "${CYAN}📋 Langkah setup Google Drive:${RESET}"
    echo "1. Jalankan: ${YELLOW}rclone config${RESET}"
    echo "2. Pilih: ${YELLOW}n${RESET} (new remote)"
    echo "3. Nama: ${YELLOW}gdrive${RESET}"
    echo "4. Storage: ${YELLOW}drive${RESET} (Google Drive)"
    echo "5. Client ID: ${YELLOW}(tekan Enter untuk default)${RESET}"
    echo "6. Client Secret: ${YELLOW}(tekan Enter untuk default)${RESET}"
    echo "7. Scope: ${YELLOW}1${RESET} (drive)"
    echo "8. Root folder: ${YELLOW}(tekan Enter untuk default)${RESET}"
    echo "9. Service account: ${YELLOW}(tekan Enter untuk default)${RESET}"
    echo "10. Auto config: ${YELLOW}y${RESET}"
    echo "11. Login ke Google Drive di browser"
    echo "12. Konfirmasi: ${YELLOW}y${RESET}"
    echo ""
    
    read -p "Apakah Anda ingin menjalankan rclone config sekarang? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rclone config
    fi
    
    # Test connection
    echo ""
    echo "${CYAN}🔍 Testing Google Drive connection...${RESET}"
    if rclone lsd gdrive: >/dev/null 2>&1; then
        echo "${GREEN}✅ Google Drive connection berhasil${RESET}"
        
        # Buat folder backup jika belum ada
        rclone mkdir "gdrive:$GDRIVE_DIR" 2>/dev/null
        echo "${GREEN}✅ Folder backup dibuat: $GDRIVE_DIR${RESET}"
    else
        echo "${RED}❌ Google Drive connection gagal${RESET}"
        echo "${YELLOW}Pastikan Anda sudah menjalankan 'rclone config' dengan benar${RESET}"
        exit 1
    fi
    
    # Buat config file
    echo ""
    echo "${CYAN}📝 Membuat config file...${RESET}"
    cat > "$CONFIG_FILE" << EOF
# Konfigurasi Backup Google Drive
BACKUP_DIR="$BACKUP_DIR"
GDRIVE_DIR="$GDRIVE_DIR"
MYSQL_USER="$MYSQL_USER"
MYSQL_PASSWORD="$MYSQL_PASSWORD"
MYSQL_CONFIG_FILE="$MYSQL_CONFIG_FILE"
VHOST_DIR="$VHOST_DIR"
RETENTION_DAYS=$RETENTION_DAYS
COMPRESS_LEVEL=$COMPRESS_LEVEL
EOF
    
    echo "${GREEN}✅ Config file dibuat: $CONFIG_FILE${RESET}"
    echo ""
    echo "${CYAN}🎉 Setup selesai! Anda bisa menjalankan backup sekarang.${RESET}"
}

# Fungsi untuk menampilkan setup cron
show_cron_setup() {
    echo "${BOLD}⏰ Cron Job Setup${RESET}"
    echo "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "${CYAN}Untuk menjalankan backup otomatis, tambahkan ke crontab:${RESET}"
    echo ""
    echo "${YELLOW}# Backup harian pada jam 2 pagi${RESET}"
    echo "${GREEN}0 2 * * * $(readlink -f "$0") >/var/log/backup-gdrive.log 2>&1${RESET}"
    echo ""
    echo "${YELLOW}# Backup mingguan (hanya database) pada hari Minggu jam 1 pagi${RESET}"
    echo "${GREEN}0 1 * * 0 $(readlink -f "$0") -b >/var/log/backup-gdrive-db.log 2>&1${RESET}"
    echo ""
    echo "${CYAN}Untuk mengedit crontab:${RESET}"
    echo "${GREEN}crontab -e${RESET}"
    echo ""
    echo "${CYAN}Untuk melihat log backup:${RESET}"
    echo "${GREEN}tail -f /var/log/backup-gdrive.log${RESET}"
    echo ""
    echo "${CYAN}Untuk membuat log rotation:${RESET}"
    echo "${GREEN}sudo logrotate -f /etc/logrotate.d/backup-gdrive${RESET}"
    echo ""
    
    # Buat logrotate config
    cat > /tmp/backup-gdrive-logrotate << EOF
/var/log/backup-gdrive*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    
    echo "${YELLOW}Config logrotate tersimpan di: /tmp/backup-gdrive-logrotate${RESET}"
    echo "${CYAN}Copy ke: sudo cp /tmp/backup-gdrive-logrotate /etc/logrotate.d/backup-gdrive${RESET}"
    echo ""
    echo "${BOLD}🔐 Keamanan MySQL:${RESET}"
    echo "${CYAN}Jika menggunakan user backup khusus, pastikan:${RESET}"
    echo "• User backup hanya memiliki permission SELECT, LOCK TABLES, SHOW VIEW"
    echo "• Jangan gunakan root MySQL untuk backup production"
    echo "• Gunakan password yang kuat untuk user backup"
    echo "• Review log backup secara berkala"
}

# Fungsi untuk mendapatkan informasi database
get_database_info() {
    local domain=$1
    local username=$2
    local doc_root=$3
    
    local db_name=""
    local db_user=""
    
    # Cek berbagai lokasi config file
    local config_files=(
        "$doc_root/wp-config.php"
        "$doc_root/config.php"
        "$doc_root/configuration.php"
        "$doc_root/config/database.php"
        "$doc_root/.env"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" && -r "$config_file" ]]; then
            # WordPress config
            if [[ "$config_file" == *"wp-config.php" ]]; then
                db_name=$(grep -oP "define\s*\(\s*['\"]DB_NAME['\"],\s*['\"]\\K[^'\"]*" "$config_file" 2>/dev/null | head -n1)
                db_user=$(grep -oP "define\s*\(\s*['\"]DB_USER['\"],\s*['\"]\\K[^'\"]*" "$config_file" 2>/dev/null | head -n1)
                break
            fi
            
            # Laravel .env
            if [[ "$config_file" == *".env" ]]; then
                db_name=$(grep -oP "DB_DATABASE=\\K.*" "$config_file" 2>/dev/null | head -n1)
                db_user=$(grep -oP "DB_USERNAME=\\K.*" "$config_file" 2>/dev/null | head -n1)
                break
            fi
            
            # Generic PHP config
            if [[ "$config_file" == *"config.php" ]]; then
                db_name=$(grep -oP "\\\$db_name\s*=\s*['\"]\\K[^'\"]*" "$config_file" 2>/dev/null | head -n1)
                if [[ -z "$db_name" ]]; then
                    db_name=$(grep -oP "\\\$database\s*=\s*['\"]\\K[^'\"]*" "$config_file" 2>/dev/null | head -n1)
                fi
                db_user=$(grep -oP "\\\$db_user\s*=\s*['\"]\\K[^'\"]*" "$config_file" 2>/dev/null | head -n1)
                break
            fi
        fi
    done
    
    # Fallback ke nama user jika tidak ditemukan
    if [[ -z "$db_name" ]]; then
        db_name="${username}_db"
    fi
    
    if [[ -z "$db_user" ]]; then
        db_user="$username"
    fi
    
    echo "${db_name}|${db_user}"
}

# Fungsi untuk backup database
backup_database() {
    local domain=$1
    local username=$2
    local doc_root=$3
    local backup_path=$4
    
    local db_info=$(get_database_info "$domain" "$username" "$doc_root")
    IFS='|' read -r db_name db_user <<< "$db_info"
    
    # Gunakan MySQL config file jika ada, atau credentials dari variabel
    local mysql_opts=""
    if [[ -f "$MYSQL_CONFIG_FILE" ]]; then
        mysql_opts="--defaults-file=$MYSQL_CONFIG_FILE"
    else
        mysql_opts="-u$MYSQL_USER"
        if [[ -n "$MYSQL_PASSWORD" ]]; then
            mysql_opts="$mysql_opts -p$MYSQL_PASSWORD"
        fi
    fi
    
    # Verifikasi database exists
    if ! mysql $mysql_opts -e "USE $db_name" 2>/dev/null; then
        echo "${YELLOW}  ⚠️  Database $db_name tidak ditemukan${RESET}"
        return 1
    fi
    
    echo "${CYAN}  📄 Backing up database: $db_name${RESET}"
    
    # Buat backup database
    local db_backup_file="$backup_path/${domain}_database_$(date +%Y%m%d_%H%M%S).sql"
    
    if mysqldump $mysql_opts \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --add-drop-table \
        --extended-insert \
        --set-gtid-purged=OFF \
        "$db_name" > "$db_backup_file" 2>/dev/null; then
        
        # Kompres database backup
        if [[ "$COMPRESS_MAX" == true ]]; then
            gzip -9 "$db_backup_file"
            db_backup_file="${db_backup_file}.gz"
        else
            gzip -$COMPRESS_LEVEL "$db_backup_file"
            db_backup_file="${db_backup_file}.gz"
        fi
        
        local db_size=$(du -h "$db_backup_file" | cut -f1)
        echo "${GREEN}  ✅ Database backup berhasil: $db_size${RESET}"
        return 0
    else
        echo "${RED}  ❌ Database backup gagal${RESET}"
        return 1
    fi
}

# Fungsi untuk backup files
backup_files() {
    local domain=$1
    local username=$2
    local doc_root=$3
    local backup_path=$4
    
    echo "${CYAN}  📁 Backing up files: $doc_root${RESET}"
    
    if [[ ! -d "$doc_root" ]]; then
        echo "${YELLOW}  ⚠️  Directory tidak ditemukan: $doc_root${RESET}"
        return 1
    fi
    
    local files_backup_file="$backup_path/${domain}_files_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Buat daftar file yang akan di-exclude
    local exclude_patterns=(
        "--exclude=*.log"
        "--exclude=*.tmp"
        "--exclude=cache/*"
        "--exclude=tmp/*"
        "--exclude=temp/*"
        "--exclude=uploads/cache/*"
        "--exclude=wp-content/cache/*"
        "--exclude=wp-content/uploads/cache/*"
        "--exclude=node_modules/*"
        "--exclude=vendor/*"
        "--exclude=.git/*"
        "--exclude=.svn/*"
        "--exclude=.DS_Store"
        "--exclude=Thumbs.db"
    )
    
    # Buat backup files
    if tar -czf "$files_backup_file" \
        "${exclude_patterns[@]}" \
        -C "$(dirname "$doc_root")" \
        "$(basename "$doc_root")" 2>/dev/null; then
        
        local files_size=$(du -h "$files_backup_file" | cut -f1)
        echo "${GREEN}  ✅ Files backup berhasil: $files_size${RESET}"
        return 0
    else
        echo "${RED}  ❌ Files backup gagal${RESET}"
        return 1
    fi
}

# Fungsi untuk upload ke Google Drive
upload_to_gdrive() {
    local backup_path=$1
    local domain=$2
    
    echo "${CYAN}  ☁️  Uploading to Google Drive...${RESET}"
    
    # Buat folder untuk domain jika belum ada
    local gdrive_domain_path="$GDRIVE_DIR/$domain/$(date +%Y-%m)"
    rclone mkdir "gdrive:$gdrive_domain_path" 2>/dev/null
    
    # Upload semua file backup
    local upload_success=true
    for backup_file in "$backup_path"/*; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file")
            echo "${CYAN}    📤 Uploading: $filename${RESET}"
            
            if rclone copy "$backup_file" "gdrive:$gdrive_domain_path" --progress 2>/dev/null; then
                echo "${GREEN}    ✅ Upload berhasil: $filename${RESET}"
            else
                echo "${RED}    ❌ Upload gagal: $filename${RESET}"
                upload_success=false
            fi
        fi
    done
    
    return $([ "$upload_success" = true ] && echo 0 || echo 1)
}

# Fungsi untuk cleanup old backups
cleanup_old_backups() {
    echo "${CYAN}🧹 Cleaning up old backups (older than $RETENTION_DAYS days)...${RESET}"
    
    # Cleanup local backups
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null
        find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null
    fi
    
    # Cleanup Google Drive backups (optional - hati-hati dengan ini)
    # rclone delete "gdrive:$GDRIVE_DIR" --min-age ${RETENTION_DAYS}d --dry-run
}

# Fungsi utama untuk backup website
backup_website() {
    local domain=$1
    local username=$2
    local doc_root=$3
    
    echo "${BOLD}🌐 Backing up website: $domain${RESET}"
    
    # Buat direktori backup
    local backup_path="$BACKUP_DIR/$domain/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_path"
    
    local backup_success=true
    
    # Backup database
    if [[ "$FILES_ONLY" != true ]]; then
        if ! backup_database "$domain" "$username" "$doc_root" "$backup_path"; then
            backup_success=false
        fi
    fi
    
    # Backup files
    if [[ "$DB_ONLY" != true ]]; then
        if ! backup_files "$domain" "$username" "$doc_root" "$backup_path"; then
            backup_success=false
        fi
    fi
    
    # Upload ke Google Drive
    if [[ "$TEST_MODE" != true && "$backup_success" == true ]]; then
        if ! upload_to_gdrive "$backup_path" "$domain"; then
            backup_success=false
        fi
    elif [[ "$TEST_MODE" == true ]]; then
        echo "${YELLOW}  🧪 Test mode: Skip upload to Google Drive${RESET}"
    fi
    
    # Cleanup local backup setelah upload
    if [[ "$backup_success" == true && "$TEST_MODE" != true ]]; then
        rm -rf "$backup_path"
        echo "${GREEN}  ✅ Local backup cleaned up${RESET}"
    fi
    
    if [[ "$backup_success" == true ]]; then
        echo "${GREEN}✅ Website backup completed: $domain${RESET}"
    else
        echo "${RED}❌ Website backup failed: $domain${RESET}"
    fi
    
    echo ""
}

# Handle special modes
if [[ "$SETUP_MODE" == true ]]; then
    setup_gdrive
    exit 0
fi

if [[ "$SETUP_MYSQL_MODE" == true ]]; then
    setup_mysql_credentials
    exit 0
fi

if [[ "$CHECK_MYSQL_MODE" == true ]]; then
    check_mysql_status
    exit 0
fi

if [[ "$SHOW_CRON" == true ]]; then
    show_cron_setup
    exit 0
fi

# Validasi requirements
echo "${BOLD}🔍 Checking requirements...${RESET}"

# Cek rclone
if ! command -v rclone >/dev/null 2>&1; then
    echo "${RED}❌ rclone tidak ditemukan. Jalankan: $0 --setup${RESET}"
    exit 1
fi

# Cek Google Drive connection
if ! rclone lsd gdrive: >/dev/null 2>&1; then
    echo "${RED}❌ Google Drive connection gagal. Jalankan: $0 --setup${RESET}"
    exit 1
fi

# Cek MySQL
if ! command -v mysql >/dev/null 2>&1; then
    echo "${RED}❌ MySQL client tidak ditemukan${RESET}"
    exit 1
fi

# Setup MySQL credentials jika belum ada
if [[ ! -f "$MYSQL_CONFIG_FILE" ]] && [[ -z "$MYSQL_PASSWORD" ]]; then
    if ! setup_mysql_credentials; then
        echo "${RED}❌ MySQL setup gagal${RESET}"
        exit 1
    fi
fi

# Cek Apache directory
if [[ ! -d "$VHOST_DIR" ]]; then
    echo "${RED}❌ Apache sites-available directory tidak ditemukan: $VHOST_DIR${RESET}"
    exit 1
fi

echo "${GREEN}✅ All requirements met${RESET}"
echo ""

# Buat backup directory
mkdir -p "$BACKUP_DIR"

# Mulai backup
echo "${BOLD}🚀 Starting backup process...${RESET}"
echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo "${CYAN}Started: $(date)${RESET}"

if [[ -n "$FILTER_USER" ]]; then
    echo "${CYAN}Filter user: $FILTER_USER${RESET}"
fi

if [[ -n "$FILTER_DOMAIN" ]]; then
    echo "${CYAN}Filter domain: $FILTER_DOMAIN${RESET}"
fi

if [[ "$FILES_ONLY" == true ]]; then
    echo "${CYAN}Mode: Files only${RESET}"
elif [[ "$DB_ONLY" == true ]]; then
    echo "${CYAN}Mode: Database only${RESET}"
fi

if [[ "$TEST_MODE" == true ]]; then
    echo "${YELLOW}Mode: Test (no upload)${RESET}"
fi

echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

# Kumpulkan website data
website_count=0
backup_success_count=0

for file in "$VHOST_DIR"/*.conf; do
    # Skip jika tidak ada file .conf atau file tidak bisa dibaca
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        continue
    fi
    
    domain=$(basename "$file" .conf)
    
    # Skip file default Apache
    if [[ "$domain" == "000-default" || "$domain" == "default-ssl" ]]; then
        continue
    fi
    
    # Skip jika domain kosong atau tidak valid
    if [[ -z "$domain" || "$domain" == "." || "$domain" == ".." ]]; then
        continue
    fi
    
    # Validasi apakah file berisi konfigurasi Apache yang valid
    if ! grep -q "VirtualHost\|ServerName\|DocumentRoot" "$file"; then
        continue
    fi
    
    # Ambil informasi website
    doc_root=$(grep -oP 'DocumentRoot\s+\K[^\s]+' "$file" | head -n1)
    username=$(echo "$doc_root" | grep -oP '/home/\K[^/]+' | head -n1)
    
    # Fallback username dari domain
    if [[ -z "$username" ]]; then
        username=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    
    # Fallback DocumentRoot
    if [[ -z "$doc_root" ]]; then
        doc_root="/home/$username/public_html"
    fi
    
    # Filter berdasarkan user
    if [[ -n "$FILTER_USER" && "$username" != "$FILTER_USER" ]]; then
        continue
    fi
    
    # Filter berdasarkan domain
    if [[ -n "$FILTER_DOMAIN" && "$domain" != *"$FILTER_DOMAIN"* ]]; then
        continue
    fi
    
    # Backup website
    if [[ -n "$domain" && -n "$username" ]]; then
        backup_website "$domain" "$username" "$doc_root"
        ((website_count++))
        
        # Hitung success rate (simplified)
        if [[ $? -eq 0 ]]; then
            ((backup_success_count++))
        fi
    fi
done

# Cleanup old backups
cleanup_old_backups

# Summary
echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}📊 Backup Summary${RESET}"
echo "${CYAN}Completed: $(date)${RESET}"
echo "${CYAN}Total websites processed: $website_count${RESET}"
echo "${CYAN}Successful backups: $backup_success_count${RESET}"

if [[ $website_count -gt 0 ]]; then
    success_rate=$(( backup_success_count * 100 / website_count ))
    echo "${CYAN}Success rate: ${success_rate}%${RESET}"
    
    if [[ $success_rate -eq 100 ]]; then
        echo "${GREEN}🎉 All backups completed successfully!${RESET}"
    elif [[ $success_rate -ge 80 ]]; then
        echo "${YELLOW}⚠️  Most backups completed successfully${RESET}"
    else
        echo "${RED}❌ Many backups failed - check logs${RESET}"
    fi
else
    echo "${YELLOW}⚠️  No websites found to backup${RESET}"
fi

echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
