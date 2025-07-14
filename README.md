# Server Management Scripts

Kumpulan script untuk mengelola website dan server berbasis Apache dengan PHP-FPM. Script ini dirancang untuk memudahkan administrasi server dalam mengelola multiple website dengan berbagai versi PHP.

## 📋 Daftar Isi

- [Fitur Utama](#fitur-utama)
- [Persyaratan Sistem](#persyaratan-sistem)
- [Instalasi](#instalasi)
- [Penggunaan](#penggunaan)
- [Script yang Tersedia](#script-yang-tersedia)
- [Konfigurasi](#konfigurasi)
- [Troubleshooting](#troubleshooting)
- [Kontribusi](#kontribusi)

## 🚀 Fitur Utama

- **Manajemen Website**: Menambah, menghapus, mengaktifkan, dan menonaktifkan website
- **Multi-PHP Support**: Beralih antara versi PHP yang berbeda untuk setiap website
- **Backup Otomatis**: Backup website dan database ke Google Drive secara otomatis
- **Monitoring**: Cek status PHP, website, dan database
- **Keamanan**: Validasi input, backup konfigurasi, dan rollback support

## 📋 Persyaratan Sistem

### Sistem Operasi
- Ubuntu 18.04+ atau Debian 9+
- CentOS 7+ atau RHEL 7+

### Software Dependencies
- **Apache 2.4+** dengan mod_rewrite
- **PHP-FPM** (multiple versions supported: 7.4, 8.0, 8.1, 8.2, 8.3)
- **MySQL/MariaDB** 5.7+ atau 10.3+
- **rclone** (untuk Google Drive integration)
- **bash** 4.0+
- **curl**, **wget**, **tar**, **gzip**

### Permissions
- Root access atau sudo privileges
- Akses ke direktori Apache sites-available/sites-enabled
- Akses ke PHP-FPM pool directory
- Akses ke MySQL untuk backup

## 🔧 Instalasi

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/server-management.git
cd server-management
```

### 2. Set Permissions
```bash
chmod +x *.sh
```

### 3. Install Dependencies

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install apache2 mysql-server php-fpm curl wget tar gzip
```

#### CentOS/RHEL:
```bash
sudo yum install httpd mysql-server php-fpm curl wget tar gzip
```

### 4. Setup Google Drive (Optional)
```bash
sudo ./backup-to-gdrive.sh --setup
```

### 5. Setup MySQL Credentials
```bash
sudo ./backup-to-gdrive.sh --setup-mysql
```

## 📖 Penggunaan

### Quick Start
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
- Validasi domain dan username
- Pembuatan VirtualHost otomatis
- Konfigurasi PHP-FPM pool
- SSL certificate setup (Let's Encrypt)
- Database creation (optional)

**Penggunaan:**
```bash
./add-website.sh
```

### 2. `delete-website.sh`
Script untuk menghapus website secara aman dengan backup.

**Fitur:**
- Backup konfigurasi sebelum penghapusan
- Konfirmasi keamanan berlapis
- Cleanup PHP-FPM pool
- Opsi untuk mempertahankan data

**Penggunaan:**
```bash
./delete-website.sh
```

### 3. `enable-website.sh`
Script untuk mengaktifkan website yang telah dinonaktifkan.

**Fitur:**
- Aktivasi Apache site
- Restart PHP-FPM pool
- Validasi konfigurasi
- Status verification

**Penggunaan:**
```bash
./enable-website.sh
```

### 4. `disable-website.sh`
Script untuk menonaktifkan website tanpa menghapus konfigurasi.

**Fitur:**
- Nonaktifkan Apache site
- Stop PHP-FPM pool
- Backup konfigurasi
- Reversible action

**Penggunaan:**
```bash
./disable-website.sh
```

### 5. `switch-php.sh`
Script untuk beralih versi PHP untuk website tertentu.

**Fitur:**
- Auto-detection versi PHP saat ini
- Compatibility checking
- Backup konfigurasi
- Rollback support
- Zero-downtime switching

**Penggunaan:**
```bash
./switch-php.sh
```

**Contoh Output:**
```
🔍 Mendeteksi versi PHP saat ini...
✅ Terdeteksi PHP version saat ini: 8.1
🔄 Akan switch PHP untuk domain: example.com
📊 Dari PHP 8.1 ke PHP 8.2
👤 Username: example_user
```

### 6. `check-php-versions.sh`
Script untuk memonitor status website dan versi PHP.

**Fitur:**
- Status website (enabled/disabled)
- Versi PHP yang digunakan
- Database information
- Export ke CSV/JSON
- Filtering dan sorting

**Penggunaan:**
```bash
./check-php-versions.sh [OPTIONS]

Options:
  -s, --summary     Tampilkan ringkasan
  -u, --user USER   Filter berdasarkan user
  -p, --php VER     Filter berdasarkan versi PHP
  -e, --export      Export ke CSV
  -j, --json        Export ke JSON
  -h, --help        Bantuan
```

### 7. `backup-to-gdrive.sh`
Script backup komprehensif ke Google Drive.

**Fitur:**
- Backup files dan database
- Kompresi otomatis
- Google Drive integration
- Retention policy
- Cron job support
- Multiple MySQL authentication methods

**Penggunaan:**
```bash
./backup-to-gdrive.sh [OPTIONS]

Options:
  -u, --user USER       Backup website user tertentu
  -d, --domain DOMAIN   Backup domain tertentu
  -f, --files-only      Backup files saja
  -b, --db-only         Backup database saja
  -c, --compress        Gunakan kompresi maksimal
  -t, --test            Test mode (tidak upload)
  --setup               Setup Google Drive
  --setup-mysql         Setup MySQL credentials
  --check-mysql         Cek status MySQL
  --cron                Tampilkan contoh cron job
```

**Setup MySQL Authentication:**
```bash
# Pilihan 1: Root tanpa password (development)
./backup-to-gdrive.sh --setup-mysql
> Pilih opsi (1-3): 1

# Pilihan 2: Root dengan password
./backup-to-gdrive.sh --setup-mysql  
> Pilih opsi (1-3): 2

# Pilihan 3: Dedicated backup user (recommended)
./backup-to-gdrive.sh --setup-mysql
> Pilih opsi (1-3): 3
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
tar -xzf /tmp/backup.tar.gz -C /home/user/
```

## 📊 Best Practices

### Security
- Gunakan dedicated MySQL user untuk backup
- Implementasikan fail2ban untuk protection
- Regular security updates
- Monitor log files secara berkala

### Performance
- Gunakan appropriate PHP version untuk setiap website
- Implementasikan caching (Redis/Memcached)
- Monitor resource usage
- Regular database optimization

### Backup Strategy
- Daily incremental backups
- Weekly full backups
- Monthly archive to different location
- Test restore procedures regularly

## 🤝 Kontribusi

### Development Setup
```bash
git clone https://github.com/yourusername/server-management.git
cd server-management
chmod +x *.sh
```

### Testing
```bash
# Test backup script
./backup-to-gdrive.sh --test

# Test PHP switching
./switch-php.sh --dry-run
```

### Submit Changes
1. Fork repository
2. Create feature branch
3. Test thoroughly
4. Submit pull request

## 📝 Changelog

### v1.0.0
- Initial release
- Basic website management
- PHP version switching
- Google Drive backup integration

### v1.1.0
- Added MySQL authentication options
- Improved error handling
- Enhanced logging
- Cron job integration

## 📞 Support

Untuk pertanyaan atau masalah:
- Buat issue di GitHub repository
- Email: support@yourcompany.com
- Documentation: https://github.com/yourusername/server-management/wiki

## 📜 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Apache Software Foundation
- PHP-FPM team
- rclone developers
- Community contributors

---

**⚠️ Disclaimer**: Scripts ini dirancang untuk environment development dan testing. Untuk production, lakukan testing menyeluruh dan sesuaikan dengan kebutuhan spesifik Anda.
