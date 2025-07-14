# Server Management Scripts

Kumpulan script untuk mengelola website dan server berbasis Apache dengan PHP-FPM. Script ini dirancang untuk memudahkan administrasi server dalam mengelola multiple website dengan berbagai versi PHP.

## �‍💻 Author & Credits

**Dibuat oleh:** Oji Fahruroji  
**Email:** ojifahru83@gmail.com  
**GitHub:** [@ojifahru](https://github.com/ojifahru)  
**Repository:** https://github.com/ojifahru/manajemen-server

Project ini dibuat dengan bantuan AI dan pastinya masih banyak kekurangan. Saya membuat project ini untuk mempermudah diri saya dalam mengelola server. Kritik, saran, dan kontribusi dari teman-teman sangat diperlukan untuk membuat project ini lebih baik.

## �📋 Daftar Isi

- [Fitur Utama](#fitur-utama)
- [Persyaratan Sistem](#persyaratan-sistem)
- [Instalasi](#instalasi)
- [Penggunaan](#penggunaan)
- [Script yang Tersedia](#script-yang-tersedia)
- [Toolkit Features](#toolkit-features)
- [Konfigurasi](#konfigurasi)
- [Troubleshooting](#troubleshooting)
- [Kontribusi](#kontribusi)
- [Changelog](#changelog)
- [Support](#support)
- [License](#license)

## 🚀 Fitur Utama

- **Toolkit Interface**: Interface terpadu untuk semua operasi server management
- **Manajemen Website**: Menambah, menghapus, mengaktifkan, dan menonaktifkan website
- **Multi-PHP Support**: Beralih antara versi PHP yang berbeda untuk setiap website
- **SSL Support**: Dukungan Let's Encrypt dan self-signed certificates
- **Backup Otomatis**: Backup website dan database ke Google Drive secara otomatis
- **Monitoring**: Cek status PHP, website, dan database
- **Auto Installation**: Script installer otomatis untuk setup lengkap
- **Keamanan**: Validasi input, backup konfigurasi, dan rollback support

## 📋 Persyaratan Sistem

### Sistem Operasi
- Ubuntu 18.04+ atau Debian 9+
- CentOS 7+ atau RHEL 7+

### Software Dependencies
- **Apache 2.4+** dengan mod_rewrite, mod_proxy_fcgi, mod_setenvif
- **PHP-FPM** (multiple versions supported):
  - PHP 7.4 (dengan extensions: mysql, curl, gd, mbstring, xml, zip, bcmath, json, intl)
  - PHP 8.0 (dengan extensions: mysql, curl, gd, mbstring, xml, zip, bcmath, intl)
  - PHP 8.1 (dengan extensions: mysql, curl, gd, mbstring, xml, zip, bcmath, intl)
  - PHP 8.2 (dengan extensions: mysql, curl, gd, mbstring, xml, zip, bcmath, intl)
  - PHP 8.3 (dengan extensions: mysql, curl, gd, mbstring, xml, zip, bcmath, intl)
- **MySQL/MariaDB** 5.7+ atau 10.3+
- **rclone** (untuk Google Drive integration)
- **certbot** dengan python3-certbot-apache (untuk Let's Encrypt SSL)
- **bash** 4.0+
- **curl**, **wget**, **tar**, **gzip**
- **software-properties-common** (Ubuntu/Debian untuk PPA)
- **yum-utils** dan **remi-release** (CentOS/RHEL untuk multiple PHP)

### PHP Extensions Requirements

Setiap versi PHP memerlukan extensions berikut untuk compatibility penuh:

#### Required Extensions:
- **mysql/mysqli** - Database connectivity
- **curl** - HTTP requests dan API calls
- **gd** - Image processing
- **mbstring** - Multi-byte string handling
- **xml** - XML processing
- **zip** - Archive handling
- **bcmath** - Arbitrary precision mathematics
- **intl** - Internationalization functions

#### Optional Extensions (Recommended):
- **opcache** - Performance optimization
- **redis** - Caching (if using Redis)
- **memcached** - Caching (if using Memcached)
- **imagick** - Advanced image processing
- **xdebug** - Development debugging (development only)

#### Check Installed Extensions:
```bash
# Check specific PHP version extensions
php7.4 -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)"
php8.0 -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)"
php8.1 -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)"
php8.2 -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)"
php8.3 -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)"

# Check all versions at once
for version in 7.4 8.0 8.1 8.2 8.3; do
    echo "PHP $version extensions:"
    php$version -m | grep -E "(mysql|curl|gd|mbstring|xml|zip|bcmath|intl)" | sort
    echo "---"
done
```

#### Install Missing Extensions:
```bash
# Ubuntu/Debian - Install missing extensions
sudo apt install -y php7.4-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo apt install -y php8.0-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo apt install -y php8.1-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo apt install -y php8.2-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo apt install -y php8.3-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}

# CentOS/RHEL - Install missing extensions
sudo yum install -y php74-php-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo yum install -y php80-php-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo yum install -y php81-php-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
sudo yum install -y php82-php-{mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
```

### Permissions
- Root access atau sudo privileges
- Akses ke direktori Apache sites-available/sites-enabled
- Akses ke PHP-FPM pool directory
- Akses ke MySQL untuk backup

## 🔧 Instalasi

### Metode 1: Instalasi Otomatis (Recommended)
```bash
# Clone repository
git clone https://github.com/ojifahru/manajemen-server.git
cd manajemen-server

# Jalankan installer otomatis
sudo ./install.sh
```

Script installer akan:
- Install semua dependencies yang diperlukan
- Setup directory structure
- Konfigurasi Apache, MySQL, dan PHP-FPM
- Install toolkit ke system PATH
- Setup bash completion dan shortcuts

### Metode 2: Instalasi Manual

#### 1. Clone Repository
```bash
git clone https://github.com/ojifahru/manajemen-server.git
cd manajemen-server
```

#### 2. Set Permissions
```bash
chmod +x *.sh
```

#### 3. Install Dependencies

##### Ubuntu/Debian:
```bash
# Update package list
sudo apt update

# Install basic dependencies
sudo apt install -y apache2 mysql-server curl wget tar gzip certbot python3-certbot-apache rclone

# Add Ondrej's PPA for multiple PHP versions
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install multiple PHP versions
sudo apt install -y php7.4-fpm php7.4-mysql php7.4-curl php7.4-gd php7.4-mbstring php7.4-xml php7.4-zip php7.4-bcmath php7.4-json php7.4-intl
sudo apt install -y php8.0-fpm php8.0-mysql php8.0-curl php8.0-gd php8.0-mbstring php8.0-xml php8.0-zip php8.0-bcmath php8.0-intl
sudo apt install -y php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip php8.1-bcmath php8.1-intl
sudo apt install -y php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-intl
sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-bcmath php8.3-intl

# Enable and start PHP-FPM services
sudo systemctl enable php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm
sudo systemctl start php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm

# Enable Apache modules
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm
sudo systemctl restart apache2
```

##### CentOS/RHEL:
```bash
# Install EPEL repository
sudo yum install -y epel-release

# Install Remi repository for multiple PHP versions
sudo yum install -y yum-utils
sudo yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

# Install basic dependencies
sudo yum install -y httpd mysql-server curl wget tar gzip certbot python3-certbot-apache rclone

# Install multiple PHP versions
sudo yum module reset php -y
sudo yum module enable php:remi-7.4 -y
sudo yum install -y php74-php-fpm php74-php-mysql php74-php-curl php74-php-gd php74-php-mbstring php74-php-xml php74-php-zip php74-php-bcmath php74-php-json php74-php-intl

sudo yum module enable php:remi-8.0 -y
sudo yum install -y php80-php-fpm php80-php-mysql php80-php-curl php80-php-gd php80-php-mbstring php80-php-xml php80-php-zip php80-php-bcmath php80-php-intl

sudo yum module enable php:remi-8.1 -y
sudo yum install -y php81-php-fpm php81-php-mysql php81-php-curl php81-php-gd php81-php-mbstring php81-php-xml php81-php-zip php81-php-bcmath php81-php-intl

sudo yum module enable php:remi-8.2 -y
sudo yum install -y php82-php-fpm php82-php-mysql php82-php-curl php82-php-gd php82-php-mbstring php82-php-xml php82-php-zip php82-php-bcmath php82-php-intl

# Enable and start services
sudo systemctl enable httpd mysql php74-php-fpm php80-php-fpm php81-php-fpm php82-php-fpm
sudo systemctl start httpd mysql php74-php-fpm php80-php-fpm php81-php-fpm php82-php-fpm
```

#### 4. Setup Google Drive (Optional)
```bash
sudo ./backup-to-gdrive.sh --setup
```

#### 5. Setup MySQL Credentials
```bash
sudo ./backup-to-gdrive.sh --setup-mysql
```

### Verifikasi Instalasi
```bash
# Cek toolkit sudah terinstall
toolkit --version

# Cek status sistem
toolkit --health-check

# Verifikasi PHP versions terinstall
php7.4 --version
php8.0 --version
php8.1 --version
php8.2 --version
php8.3 --version

# Cek PHP-FPM services
sudo systemctl status php7.4-fpm
sudo systemctl status php8.0-fpm
sudo systemctl status php8.1-fpm
sudo systemctl status php8.2-fpm
sudo systemctl status php8.3-fpm

# Cek Apache modules
sudo a2enmod -l | grep -E "(proxy|fcgi|setenvif)"

# Test semua PHP versions
./check-php-versions.sh
```

## 📖 Penggunaan

### Menggunakan Toolkit (Recommended)
```bash
# Jalankan toolkit interactive menu
toolkit

# Atau gunakan langsung
toolkit --add-website
toolkit --list-websites
toolkit --system-health
toolkit --backup-all
```

### Menggunakan Script Individual

#### Quick Start
```bash
# Cek status semua website
./check-php-versions.sh

# Menambah website baru
./add-website.sh

# Backup semua website ke Google Drive
./backup-to-gdrive.sh

# Switch versi PHP untuk website tertentu
./switch-php.sh
```

## 📁 Script yang Tersedia

### 1. `add-website.sh`
Script untuk menambah website baru dengan konfigurasi Apache dan PHP-FPM.

**Fitur:**
- Validasi domain dan username otomatis
- Pembuatan VirtualHost Apache secara otomatis
- Konfigurasi PHP-FPM pool dengan user terpisah
- SSL certificate setup (Let's Encrypt ready)
- Database creation (optional)
- Folder structure creation dengan permissions yang benar
- Logging semua aktivitas

**Penggunaan:**
```bash
./add-website.sh
```

**Contoh Interactive Setup:**
```
🌐 Masukkan nama domain (contoh: example.com): mysite.local
👤 Username akan dibuat: mysite_local
📁 Document Root: /home/mysite_local/public_html
🐘 PHP Version (8.1): 8.2
🗄️ Buat database? (y/N): y
```

### 2. `delete-website.sh`
Script untuk menghapus website secara aman dengan backup lengkap.

**Fitur:**
- Backup konfigurasi sebelum penghapusan
- Konfirmasi keamanan berlapis (triple confirmation)
- Cleanup PHP-FPM pool dan socket
- Opsi untuk mempertahankan data user
- Rollback capability dengan backup
- Logging aktivitas penghapusan

**Penggunaan:**
```bash
./delete-website.sh
```

**Safety Features:**
- Backup otomatis ke `/root/website-deletion-backups/`
- Konfirmasi dengan mengetik nama domain
- Opsi untuk mempertahankan home directory
- Reversible action dalam 24 jam

### 3. `disable-website.sh`
Script untuk menonaktifkan website tanpa menghapus konfigurasi.

**Fitur:**
- Nonaktifkan Apache site (a2dissite)
- Stop dan disable PHP-FPM pool
- Backup konfigurasi sebelum disable
- Reversible action
- Maintenance mode support
- Status verification

**Penggunaan:**
```bash
./disable-website.sh
```

**Keunggulan:**
- Zero data loss - hanya menonaktifkan
- Dapat diaktifkan kembali dengan `enable-website.sh`
- Backup konfigurasi otomatis
- Maintenance page option

### 4. `enable-website.sh`
Script untuk mengaktifkan website yang telah dinonaktifkan.

**Fitur:**
- Aktivasi Apache site (a2ensite)
- Start dan enable PHP-FPM pool
- Validasi konfigurasi sebelum aktivasi
- Status verification lengkap
- SSL certificate check
- Database connectivity test

**Penggunaan:**
```bash
./enable-website.sh
```

**Verification Steps:**
- Apache configuration test
- PHP-FPM socket availability
- Database connection test
- SSL certificate validation
- Website accessibility test

### 5. `website-info.sh`
Script untuk menampilkan informasi lengkap tentang website di server.

**Fitur:**
- Informasi domain dan user
- Status website (enabled/disabled)
- Versi PHP yang digunakan
- Database information
- Path dan konfigurasi
- Resource usage
- SSL certificate info
- Export ke berbagai format

**Penggunaan:**
```bash
./website-info.sh [OPTIONS]

Options:
  -u, --user USER     Filter berdasarkan user
  -d, --domain DOMAIN Filter berdasarkan domain
  -s, --summary       Tampilkan ringkasan
  -v, --verbose       Tampilkan detail lengkap
  -e, --export        Export ke CSV
  -j, --json          Export ke JSON
  -h, --help          Bantuan
```

**Contoh Output:**
```
📋 WEBSITE INFORMATION
══════════════════════════════════════════════════════════════
🌐 Domain        : example.com
👤 Username      : example_user
🐘 PHP Version   : 8.2
🗄️ Database      : example_db
📁 Document Root : /home/example_user/public_html
🟢 Status        : ENABLED
🔒 SSL           : Valid until 2024-12-31
📊 Disk Usage    : 150MB
🔗 Socket        : /run/php/php8.2-fpm-example_user.sock
```

### 6. `switch-php.sh`
Script untuk beralih versi PHP untuk website tertentu dengan safety checks.

**Fitur:**
- Auto-detection versi PHP saat ini
- Compatibility checking antar versi
- Backup konfigurasi sebelum switch
- Rollback support jika gagal
- Zero-downtime switching
- Extension compatibility check
- Performance monitoring

**Penggunaan:**
```bash
./switch-php.sh
```

**Safety Features:**
```
🔍 Mendeteksi versi PHP saat ini...
✅ Terdeteksi PHP version saat ini: 8.1
⚠️ PERHATIAN: Ada potential compatibility issues!
🔄 Akan switch PHP untuk domain: example.com
📊 Dari PHP 8.1 ke PHP 8.2
👤 Username: example_user

🧪 Testing website dengan PHP 8.2...
✅ Website test passed
🎉 Versi PHP berhasil diubah!
```

**Rollback Instructions:**
Jika terjadi masalah, rollback dapat dilakukan dengan:
```bash
# Gunakan backup files yang dibuat otomatis
cp /root/php-switch-backups/backup_file.vhost.backup /etc/apache2/sites-available/domain.conf
mv /etc/php/8.1/fpm/pool.d/user.conf.disabled /etc/php/8.1/fpm/pool.d/user.conf
sudo systemctl restart php8.1-fpm apache2
```

### 7. `backup-to-gdrive.sh`
Script backup komprehensif untuk website dan database ke Google Drive.

**Fitur:**
- Backup files dan database terpisah atau bersamaan
- Kompresi otomatis dengan level yang dapat disesuaikan
- Google Drive integration dengan rclone
- Retention policy untuk manajemen storage
- Cron job support untuk automation
- Multiple MySQL authentication methods
- Test mode untuk validasi tanpa upload
- Incremental backup support
- Encryption support untuk data sensitif

**Penggunaan:**
```bash
./backup-to-gdrive.sh [OPTIONS]

Options:
  -u, --user USER       Backup website user tertentu
  -d, --domain DOMAIN   Backup domain tertentu
  -f, --files-only      Backup files saja (tanpa database)
  -b, --db-only         Backup database saja (tanpa files)
  -c, --compress        Gunakan kompresi maksimal
  -t, --test            Test mode (tidak upload ke Google Drive)
  --setup               Setup Google Drive credentials
  --setup-mysql         Setup MySQL credentials
  --check-mysql         Cek status MySQL user dan permissions
  --cron                Tampilkan contoh cron job
```

**Setup MySQL Authentication:**
```bash
# Pilihan 1: Root tanpa password (development only)
./backup-to-gdrive.sh --setup-mysql
> Pilih opsi (1-3): 1

# Pilihan 2: Root dengan password
./backup-to-gdrive.sh --setup-mysql  
> Pilih opsi (1-3): 2

# Pilihan 3: Dedicated backup user (recommended for production)
./backup-to-gdrive.sh --setup-mysql
> Pilih opsi (1-3): 3
```

**Contoh Backup Process:**
```
🔍 Checking requirements...
✅ All requirements met

🚀 Starting backup process...
═══════════════════════════════════════════════════════════════
Started: 2024-07-14 02:00:01
═══════════════════════════════════════════════════════════════

🌐 Backing up website: example.com
  📄 Backing up database: example_db
  ✅ Database backup berhasil: 2.5MB
  📁 Backing up files: /home/example_user/public_html
  ✅ Files backup berhasil: 45MB
  ☁️  Uploading to Google Drive...
    📤 Uploading: example.com_database_20240714_020001.sql.gz
    ✅ Upload berhasil: example.com_database_20240714_020001.sql.gz
    📤 Uploading: example.com_files_20240714_020001.tar.gz
    ✅ Upload berhasil: example.com_files_20240714_020001.tar.gz
  ✅ Local backup cleaned up
✅ Website backup completed: example.com

🧹 Cleaning up old backups (older than 30 days)...

═══════════════════════════════════════════════════════════════
📊 Backup Summary
Completed: 2024-07-14 02:05:30
Total websites processed: 3
Successful backups: 3
Success rate: 100%
🎉 All backups completed successfully!
═══════════════════════════════════════════════════════════════
```

### 8. `toolkit.sh`
Script unified interface untuk semua operasi server management.

**Fitur:**
- Interactive menu system dengan color-coded interface
- Command-line interface untuk automation
- System health monitoring dan reporting
- Bulk operations untuk multiple websites
- Log viewing dan analysis
- Comprehensive help system

**Penggunaan:**
```bash
# Interactive mode
./toolkit.sh

# Command line mode
./toolkit.sh --add-website
./toolkit.sh --system-health
./toolkit.sh --backup-all
./toolkit.sh --help
```

### 9. `install.sh`
Script installer otomatis untuk setup lengkap toolkit.

**Fitur:**
- Automatic dependency installation
- System configuration dan optimization
- Directory structure creation
- Service setup dan configuration
- Security hardening
- Desktop integration

**Penggunaan:**
```bash
sudo ./install.sh
```

### 10. `uninstall.sh`
Script uninstaller yang aman untuk menghapus toolkit.

**Fitur:**
- Safe removal dengan confirmation
- Selective uninstallation options
- Backup preservation
- Complete cleanup options
- System restoration

**Penggunaan:**
```bash
sudo ./uninstall.sh
```

**Safety Features:**
- Triple confirmation untuk uninstallation
- Preserves website data dan SSL certificates
- Optional package removal
- Backup cleanup options

## 🛠️ Toolkit Features

Server Management Toolkit menyediakan interface terpadu untuk semua operasi server management. Toolkit ini menggabungkan semua script individual dalam satu interface yang mudah digunakan.

### Interactive Menu System
```bash
toolkit
```

Menu utama toolkit menyediakan:
- **Website Management**: Add, delete, enable/disable websites
- **PHP Management**: Switch PHP versions, check PHP status
- **Backup Operations**: Backup to Google Drive, restore operations
- **System Monitoring**: Health checks, log viewing, resource monitoring
- **Bulk Operations**: Mass operations on multiple websites

### Command Line Interface
```bash
# Quick operations
toolkit --add-website
toolkit --delete-website
toolkit --switch-php
toolkit --backup-all
toolkit --system-health
toolkit --list-websites
toolkit --view-logs
```

### System Integration
- **Global Commands**: Available dari semua directory
- **Bash Completion**: Auto-complete untuk semua commands
- **Desktop Shortcuts**: GUI launcher untuk toolkit
- **Logging**: Comprehensive logging untuk semua operations
- **Error Handling**: Advanced error handling dan recovery

### Health Monitoring
```bash
toolkit --health-check
```

Monitoring meliputi:
- Apache service status
- MySQL connectivity
- PHP-FPM pools status
- Disk usage dan memory
- SSL certificate expiry
- Website accessibility

### Bulk Operations
```bash
toolkit --bulk-operations
```

Operasi bulk untuk:
- Enable/disable multiple websites
- Backup multiple websites
- PHP version updates
- SSL certificate renewal
- Health checks semua websites

## 🔧 Workflow Lengkap

### Menambah Website Baru
```bash
# 1. Buat website baru
./add-website.sh

# 2. Cek informasi website
./website-info.sh -d example.com

# 3. Setup backup otomatis
./backup-to-gdrive.sh --setup
./backup-to-gdrive.sh --setup-mysql

# 4. Test backup
./backup-to-gdrive.sh -d example.com -t
```

### Mengelola Website Existing
```bash
# Cek status semua website
./website-info.sh -s

# Nonaktifkan website sementara
./disable-website.sh

# Aktifkan kembali
./enable-website.sh

# Switch versi PHP
./switch-php.sh

# Backup website tertentu
./backup-to-gdrive.sh -d example.com
```

### Menghapus Website
```bash
# Backup dulu sebelum hapus
./backup-to-gdrive.sh -d example.com

# Hapus website
./delete-website.sh

# Verifikasi penghapusan
./website-info.sh -d example.com
```

## ⚙️ Konfigurasi

### Apache Configuration
Scripts menggunakan direktori standar Apache:
- `/etc/apache2/sites-available/` - Konfigurasi VirtualHost
- `/etc/apache2/sites-enabled/` - Symlink untuk website aktif

### PHP-FPM Configuration
- `/etc/php/{version}/fpm/pool.d/` - Pool configurations
- `/run/php/php{version}-fpm-{user}.sock` - Socket files

### MySQL Configuration
File konfigurasi MySQL disimpan di:
- `/root/.my.cnf` - Credentials untuk backup
- `/etc/backup-gdrive.conf` - Konfigurasi backup

### Backup Configuration
```bash
# Edit konfigurasi backup
sudo nano /etc/backup-gdrive.conf

# Contoh konfigurasi:
BACKUP_DIR="/tmp/website-backups"
GDRIVE_DIR="/Website-Backups"
RETENTION_DAYS=30
COMPRESS_LEVEL=6
```

### Post-Installation Configuration

#### Ubuntu/Debian:
```bash
# Configure PHP-FPM pool directories
sudo mkdir -p /etc/php/{7.4,8.0,8.1,8.2,8.3}/fpm/pool.d

# Set proper permissions
sudo chown -R root:root /etc/php/*/fpm/pool.d
sudo chmod 755 /etc/php/*/fpm/pool.d

# Configure Apache for PHP-FPM
sudo a2enconf php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm

# Configure PHP default version (optional)
sudo update-alternatives --config php

# Test configuration
sudo apache2ctl configtest
sudo nginx -t 2>/dev/null || echo "Nginx not installed (OK)"
```

#### CentOS/RHEL:
```bash
# Configure SELinux for PHP-FPM (if enabled)
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_execmem 1

# Configure firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Test configuration
sudo httpd -t
```

#### Common Configuration:
```bash
# Setup MySQL secure installation
sudo mysql_secure_installation

# Create backup directories
sudo mkdir -p /root/{website-config-backups,website-deletion-backups,php-switch-backups}
sudo chmod 700 /root/*-backups

# Setup logrotate
sudo tee /etc/logrotate.d/server-management > /dev/null <<EOF
/var/log/website-management.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
```

## 🎯 Use Cases & Skenario

### Skenario 1: Development ke Production
```bash
# Development setup
./add-website.sh
# Input: dev.example.com, PHP 8.2, dengan database

# Test website
./website-info.sh -d dev.example.com -v

# Backup development
./backup-to-gdrive.sh -d dev.example.com -t

# Production deployment
./add-website.sh
# Input: example.com, PHP 8.1 (stable), dengan database

# Restore data dari backup development
# (manual restore dari Google Drive)
```

### Skenario 2: PHP Version Migration
```bash
# Cek versi PHP saat ini
./website-info.sh -s

# Backup sebelum switch
./backup-to-gdrive.sh -d example.com

# Switch ke PHP versi baru
./switch-php.sh
# Input: example.com, dari 8.1 ke 8.2

# Verifikasi setelah switch
./website-info.sh -d example.com -v

# Rollback jika ada masalah
# (gunakan backup yang dibuat otomatis)
```

### Skenario 3: Server Maintenance
```bash
# Nonaktifkan semua website
for domain in $(./website-info.sh -s | grep "Domain" | cut -d: -f2); do
    ./disable-website.sh $domain
done

# Lakukan maintenance server
# (update system, restart services, dll)

# Aktifkan kembali semua website
for domain in $(./website-info.sh -s | grep "Domain" | cut -d: -f2); do
    ./enable-website.sh $domain
done
```

### Skenario 4: Disaster Recovery
```bash
# Jika server crash, restore dari backup
# 1. Setup server baru
# 2. Install dependencies
# 3. Setup scripts
# 4. Restore websites dari Google Drive

# Contoh restore website
./add-website.sh
# Input: example.com (buat struktur dasar)

# Download backup dari Google Drive
rclone copy gdrive:/Website-Backups/example.com/2024-07/ /tmp/restore/

# Restore files
tar -xzf /tmp/restore/example.com_files_*.tar.gz -C /home/example_user/

# Restore database
gunzip /tmp/restore/example.com_database_*.sql.gz
mysql -u root example_db < /tmp/restore/example.com_database_*.sql
```

## 🔄 Automation dengan Cron

### Setup Cron Job
```bash
# Edit crontab
crontab -e

# Backup harian pada jam 2 pagi
0 2 * * * /path/to/backup-to-gdrive.sh >/var/log/backup-gdrive.log 2>&1

# Backup mingguan (database saja) pada hari Minggu
0 1 * * 0 /path/to/backup-to-gdrive.sh -b >/var/log/backup-gdrive-db.log 2>&1
```

### Log Rotation
```bash
# Buat logrotate config
sudo nano /etc/logrotate.d/backup-gdrive

/var/log/backup-gdrive*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

## 🔍 Monitoring dan Troubleshooting

### Real-time Monitoring
```bash
# Monitor semua website
watch -n 30 './website-info.sh -s'

# Monitor backup logs
tail -f /var/log/backup-gdrive.log

# Monitor PHP-FPM status
systemctl status php8.1-fpm php8.2-fpm

# Monitor Apache sites
apache2ctl -S

# Monitor disk usage
df -h /home/*/public_html
```

### Health Check Script
```bash
# Buat health check sederhana
#!/bin/bash
echo "🏥 Server Health Check - $(date)"
echo "════════════════════════════════════════"

# Cek Apache
if systemctl is-active apache2 &>/dev/null; then
    echo "✅ Apache: Running"
else
    echo "❌ Apache: Stopped"
fi

# Cek PHP-FPM versions
for php_ver in 7.4 8.0 8.1 8.2; do
    if systemctl is-active php$php_ver-fpm &>/dev/null; then
        echo "✅ PHP $php_ver: Running"
    else
        echo "⚠️  PHP $php_ver: Stopped"
    fi
done

# Cek MySQL
if systemctl is-active mysql &>/dev/null; then
    echo "✅ MySQL: Running"
else
    echo "❌ MySQL: Stopped"
fi

# Cek website status
echo ""
echo "🌐 Website Status:"
./website-info.sh -s
```

### Log Files
```bash
# Website management logs
tail -f /var/log/website-management.log

# Backup logs
tail -f /var/log/backup-gdrive.log

# Apache error logs
tail -f /var/log/apache2/error.log

# PHP-FPM logs
tail -f /var/log/php{version}-fpm.log
```

### Common Issues

#### 1. MySQL Connection Error
```bash
# Cek status MySQL
sudo systemctl status mysql

# Setup ulang MySQL credentials
./backup-to-gdrive.sh --setup-mysql

# Test MySQL connection
./backup-to-gdrive.sh --check-mysql
```

#### 2. PHP-FPM Socket Error
```bash
# Cek status PHP-FPM
sudo systemctl status php8.1-fpm

# Restart PHP-FPM
sudo systemctl restart php8.1-fpm

# Cek socket file
ls -la /run/php/
```

#### 3. Apache Configuration Error
```bash
# Test Apache config
sudo apache2ctl configtest

# Reload Apache
sudo systemctl reload apache2

# Cek enabled sites
sudo a2ensite -l
```

#### 4. Google Drive Upload Error
```bash
# Test rclone connection
rclone lsd gdrive:

# Reauthorize rclone
rclone config reconnect gdrive:

# Check rclone config
rclone config show
```

#### 0. PHP Installation Issues
```bash
# Jika PHP version tidak terdeteksi
# Ubuntu/Debian:
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Jika PHP-FPM tidak bisa start
sudo systemctl status php8.2-fpm  # Check error message
sudo journalctl -u php8.2-fpm     # Check detailed logs

# Jika socket file tidak ada
sudo systemctl restart php8.2-fpm
ls -la /run/php/

# Jika Apache tidak bisa connect ke PHP-FPM
sudo a2enmod proxy_fcgi setenvif
sudo systemctl restart apache2

# Test PHP-FPM socket
sudo -u www-data php8.2-fpm -t
```

### Rollback Procedures

#### PHP Version Rollback
```bash
# Gunakan backup files dari switch-php.sh
cp /root/php-switch-backups/backup_file.vhost.backup /etc/apache2/sites-available/domain.conf
mv /etc/php/8.1/fpm/pool.d/user.conf.disabled /etc/php/8.1/fpm/pool.d/user.conf
sudo systemctl restart php8.1-fpm apache2
```

#### Website Restoration
```bash
# Restore dari Google Drive backup
rclone copy gdrive:/Website-Backups/domain.com/backup.tar.gz /tmp/
tar -xzf /tmp/backup.tar.gz -C /home/username/
```

## 📊 Best Practices

### Security Best Practices
```bash
# 1. Gunakan dedicated backup user
./backup-to-gdrive.sh --setup-mysql
# Pilih opsi 3 (dedicated backup user)

# 2. Set proper file permissions
chmod 600 /root/.my.cnf
chmod 700 /root/php-switch-backups/
chmod 755 /home/*/public_html/

# 3. Regular security updates
apt update && apt upgrade -y
# atau untuk CentOS: yum update -y

# 4. Monitor logs secara berkala
tail -f /var/log/website-management.log
tail -f /var/log/backup-gdrive.log
tail -f /var/log/apache2/error.log

# 5. Implementasikan fail2ban
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

### Security Checklist
- [ ] MySQL root password di-set (jangan kosong)
- [ ] Dedicated backup user dengan permission minimal
- [ ] File permissions di-set dengan benar
- [ ] Firewall dikonfigurasi (UFW/iptables)
- [ ] SSL certificates untuk semua website
- [ ] Regular backup testing
- [ ] Log monitoring dan alerting
- [ ] Fail2ban untuk brute force protection
- [ ] Regular security updates

### Performance Optimization
- Gunakan dedicated MySQL user untuk backup
- Implementasikan fail2ban untuk protection
- Regular security updates
- Monitor log files secara berkala

### Performance Optimization
```bash
# 1. Optimize PHP-FPM settings
# Edit /etc/php/8.2/fpm/pool.d/www.conf
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35

# 2. Enable Apache modules
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod deflate
a2enmod expires

# 3. Optimize MySQL
# Edit /etc/mysql/mysql.conf.d/mysqld.cnf
innodb_buffer_pool_size = 1G
query_cache_size = 128M
query_cache_type = 1

# 4. Monitor resource usage
./website-info.sh -v  # Cek disk usage per website
htop  # Monitor CPU dan memory
iotop  # Monitor disk I/O
```

### Backup Strategy
- Daily incremental backups
- Weekly full backups
- Monthly archive to different location
- Test restore procedures regularly

- Test restore procedures regularly

## ❓ FAQ (Frequently Asked Questions)

### Q: Apakah script ini bisa digunakan untuk production?
**A:** Ya, tetapi dengan beberapa catatan:
- Lakukan testing menyeluruh di environment development
- Gunakan dedicated backup user untuk MySQL
- Implementasikan monitoring dan alerting
- Set proper file permissions dan security
- Regular backup testing

### Q: Bagaimana jika backup ke Google Drive gagal?
**A:** Script memiliki beberapa mekanisme fallback:
```bash
# Cek Google Drive connection
./backup-to-gdrive.sh --check-mysql
rclone lsd gdrive:

# Reauthorize jika perlu
rclone config reconnect gdrive:

# Backup lokal akan tetap tersimpan jika upload gagal
ls -la /tmp/website-backups/
```

### Q: Bisakah menggunakan multiple versi PHP bersamaan?
**A:** Ya, setiap website bisa menggunakan versi PHP yang berbeda:
```bash
# Cek versi PHP per website
./website-info.sh -s

# Switch versi PHP per website
./switch-php.sh
```

### Q: Bagaimana cara restore website dari backup?
**A:** Proses restore manual:
```bash
# 1. Download backup dari Google Drive
rclone copy gdrive:/Website-Backups/domain.com/backup.tar.gz /tmp/

# 2. Extract files
tar -xzf /tmp/backup.tar.gz -C /home/username/

# 3. Restore database
gunzip /tmp/database_backup.sql.gz
mysql -u root database_name < /tmp/database_backup.sql

# 4. Set permissions
chown -R username:username /home/username/public_html/
chmod -R 755 /home/username/public_html/
```

### Q: Apakah ada limit untuk jumlah website?
**A:** Tidak ada limit dari script, tetapi tergantung pada:
- Spesifikasi server (RAM, CPU, disk)
- Konfigurasi PHP-FPM (max_children)
- Konfigurasi Apache (MaxRequestWorkers)
- Database performance

### Q: Bagaimana cara monitoring otomatis?
**A:** Setup monitoring dengan cron:
```bash
# Health check setiap 5 menit
*/5 * * * * /path/to/health-check.sh

# Alert jika ada website down
*/10 * * * * /path/to/website-monitor.sh

# Daily report
0 6 * * * /path/to/daily-report.sh
```

### Q: Apakah script kompatibel dengan panel control?
**A:** Script ini dirancang untuk raw server management. Untuk panel seperti cPanel, Plesk, atau DirectAdmin, mungkin perlu modifikasi path dan konfigurasi.

### Q: Bagaimana cara migrate dari server lama?
**A:** Proses migration:
```bash
# 1. Backup semua website di server lama
./backup-to-gdrive.sh

# 2. Setup server baru dengan script ini
# 3. Install dependencies
# 4. Setup Google Drive access
# 5. Restore website satu per satu
```

## 🤝 Kontribusi

Project ini dibuat dengan bantuan AI dan masih banyak kekurangan. Kritik, saran, dan kontribusi dari teman-teman sangat diperlukan untuk membuat project ini lebih baik.

### Development Setup
```bash
git clone https://github.com/ojifahru/manajemen-server.git
cd manajemen-server
chmod +x *.sh
```

### Testing Environment
```bash
# Test backup script (tanpa upload)
./backup-to-gdrive.sh --test

# Test MySQL setup
./backup-to-gdrive.sh --check-mysql

# Test website info
./website-info.sh -s

# Test PHP switching (dengan confirmation)
./switch-php.sh
```

### Contribution Guidelines
1. Fork repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Test thoroughly di environment development
4. Commit dengan pesan yang jelas
5. Submit pull request dengan deskripsi lengkap
6. Pastikan semua tests pass

### Code Style
- Gunakan bash strict mode: `set -euo pipefail`
- Proper error handling dengan trap
- Consistent naming convention
- Comprehensive logging
- Input validation untuk semua user input

### Cara Berkontribusi
- 🐛 **Bug Reports**: Laporkan bug melalui GitHub Issues
- 💡 **Feature Requests**: Usulkan fitur baru melalui GitHub Discussions
- 📖 **Documentation**: Perbaiki atau tambahkan dokumentasi
- 🔧 **Code**: Kontribusi code untuk perbaikan atau fitur baru
- 🧪 **Testing**: Bantu testing di berbagai environment

### Apa yang Dibutuhkan
- Testing di berbagai distribusi Linux
- Dokumentasi yang lebih baik
- Penambahan fitur monitoring
- Optimasi performa
- Security improvements
- UI/UX improvements untuk toolkit

## 📝 Changelog

### v1.0.0 (Initial Release)
- ✅ Basic website management (add, delete, enable, disable)
- ✅ PHP version switching dengan auto-detection
- ✅ Google Drive backup integration
- ✅ MySQL multiple authentication methods
- ✅ Comprehensive logging dan error handling

### v1.1.0 (Enhanced Features)
- ✅ Added website-info.sh untuk monitoring
- ✅ Improved error handling dan rollback capabilities
- ✅ Enhanced logging dengan rotation
- ✅ Cron job integration dan automation
- ✅ Security improvements

### v1.2.0 (Planned Features)
- 🔄 SSL certificate automation (Let's Encrypt)
- 🔄 Database optimization tools
- 🔄 Performance monitoring dashboard
- 🔄 Multi-server support
- 🔄 Web interface (optional)

## 📞 Support

### Untuk Bantuan
- 📧 Email: ojifahru83@gmail.com
- 🐙 GitHub Issues: https://github.com/ojifahru/manajemen-server/issues
- 📚 Documentation: https://github.com/ojifahru/manajemen-server/wiki
- 💬 Discussions: https://github.com/ojifahru/manajemen-server/discussions

### Pelaporan Bug
Saat melaporkan bug, sertakan:
- Versi OS dan distribusi
- Versi PHP yang digunakan
- Log error yang relevan
- Langkah-langkah untuk reproduce
- Expected vs actual behavior

### Feature Request
Untuk request fitur baru:
- Jelaskan use case dan kebutuhan
- Sertakan contoh implementasi jika ada
- Diskusikan impact terhadap existing features

### Dukungan Project
Jika project ini membantu Anda, dukung dengan:
- ⭐ Star repository di GitHub
- 🐛 Laporkan bug yang ditemukan
- 💡 Berikan saran improvement
- 📖 Perbaiki dokumentasi
- 🔄 Share ke teman-teman developer

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Apache Software Foundation** - Web server technology
- **PHP-FPM Team** - FastCGI Process Manager
- **rclone Developers** - Cloud storage integration
- **MySQL/MariaDB Team** - Database management
- **Linux Community** - Operating system foundation
- **GitHub Community** - Code hosting dan collaboration

## 📋 Requirements Summary

| Component | Minimum Version | Recommended |
|-----------|----------------|-------------|
| Ubuntu/Debian | 18.04/9 | 20.04/11 |
| Apache | 2.4 | 2.4.41+ |
| PHP-FPM | 7.4 | 8.1+ |
| MySQL/MariaDB | 5.7/10.3 | 8.0/10.6 |
| rclone | 1.50 | Latest |
| Bash | 4.0 | 5.0+ |

## 🚀 Quick Start Guide

```bash
# 1. Clone repository
git clone https://github.com/ojifahru/manajemen-server.git
cd manajemen-server

# 2. Set permissions
chmod +x *.sh

# 3. Setup backup (optional)
./backup-to-gdrive.sh --setup
./backup-to-gdrive.sh --setup-mysql

# 4. Add your first website
./add-website.sh

# 5. Check website status
./website-info.sh -s

# 6. Setup automated backup
crontab -e
# Add: 0 2 * * * /path/to/backup-to-gdrive.sh
```

## 📜 License

Project ini tersedia di bawah MIT License - lihat file [LICENSE](LICENSE) untuk detail.

## 🙏 Acknowledgments

- Terima kasih kepada komunitas open source yang telah menginspirasi
- Terima kasih kepada AI yang membantu dalam development
- Terima kasih kepada semua contributor dan tester

## 📈 Project Status

Project ini masih dalam tahap pengembangan aktif. Feedback dan kontribusi sangat diterima!

**Repository:** https://github.com/ojifahru/manajemen-server  
**Author:** Oji Fahruroji (ojifahru83@gmail.com)  
**Last Updated:** July 2025

---

**⭐ Jika project ini membantu Anda, jangan lupa untuk memberikan star di GitHub!**

---

**⚠️ Important Disclaimer**: 
- Scripts ini dirancang untuk environment development dan testing
- Untuk production, lakukan testing menyeluruh terlebih dahulu
- Selalu backup data penting sebelum menjalankan script
- Gunakan dedicated backup user untuk MySQL production
- Monitor logs secara berkala untuk memastikan semua berjalan lancar

**🔒 Security Note**: 
- Jangan commit file yang berisi password ke repository
- Gunakan proper file permissions untuk sensitive files
- Implementasikan firewall dan security best practices
- Regular security updates untuk semua components

**📈 Performance Note**: 
- Monitor resource usage server secara berkala
- Adjust PHP-FPM settings sesuai kebutuhan
- Implementasikan caching untuk website dengan traffic tinggi
- Regular database maintenance dan optimization
