#!/bin/bash

# Server Management Toolkit Installer
# Automated installation and setup script
# Version: 1.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Configuration
INSTALL_DIR="/opt/server-management"
BIN_DIR="/usr/local/bin"
LOG_DIR="/var/log"
CONFIG_DIR="/etc"

# Display header
show_header() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════    echo -e "${BOLD}🐘 PHP VERSIONS INSTALLED:${RESET}"
    for version in "${php_versions[@]}"; do════╗${RESET}"
    echo -e "${CYAN}║${RESET}${BOLD}            SERVER MANAGEMENT TOOLKIT INSTALLER              ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Version: 1.0                                               ${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Author: Oji Fahruroji (ojifahru83@gmail.com)              ${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Date: $(date '+%Y-%m-%d %H:%M:%S')                                   ${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Installer harus dijalankan sebagai root${RESET}"
        echo -e "${YELLOW}   Gunakan: sudo $0${RESET}"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo -e "${RED}❌ Tidak dapat mendeteksi OS${RESET}"
        exit 1
    fi
    
    echo -e "${CYAN}🖥️  Detected OS: $OS $VERSION${RESET}"
}

# Check system requirements
check_requirements() {
    echo -e "${CYAN}🔍 Checking system requirements...${RESET}"
    
    # Check if this is Ubuntu/Debian
    if [[ "$OS" != *"Ubuntu"* && "$OS" != *"Debian"* ]]; then
        echo -e "${YELLOW}⚠️  This toolkit is designed for Ubuntu/Debian systems${RESET}"
        echo -e "${YELLOW}   It may work on other systems but is not tested${RESET}"
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space (minimum 1GB)
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 1048576 ]; then
        echo -e "${RED}❌ Insufficient disk space. Minimum 1GB required${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ System requirements met${RESET}"
}

# Install dependencies
install_dependencies() {
    echo -e "${CYAN}📦 Installing dependencies...${RESET}"
    
    # Update package list
    echo -e "${CYAN}   Updating package list...${RESET}"
    apt update -qq
    
    # Install basic packages first
    echo -e "${CYAN}   Installing basic packages...${RESET}"
    basic_packages=(
        "apache2"
        "mysql-server"
        "curl"
        "wget"
        "openssl"
        "certbot"
        "python3-certbot-apache"
        "rclone"
        "bc"
        "jq"
        "software-properties-common"
    )
    
    for package in "${basic_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo -e "${CYAN}   Installing $package...${RESET}"
            apt install -y "$package" || {
                echo -e "${YELLOW}⚠️  Failed to install $package, continuing...${RESET}"
            }
        else
            echo -e "${GREEN}   ✅ $package already installed${RESET}"
        fi
    done
    
    # Install multiple PHP versions with extensions
    echo -e "${CYAN}   Installing PHP versions and extensions...${RESET}"
    # php_versions array is set by select_php_versions() function
    php_extensions=("fpm" "mysql" "curl" "gd" "mbstring" "xml" "zip" "bcmath" "intl" "opcache")
    
    for version in "${php_versions[@]}"; do
        echo -e "${CYAN}   Installing PHP $version...${RESET}"
        
        # Install PHP-FPM and extensions for this version
        php_packages=()
        for ext in "${php_extensions[@]}"; do
            if [[ "$version" == "7.4" && "$ext" == "intl" ]]; then
                # PHP 7.4 has different intl package name sometimes
                php_packages+=("php$version-$ext")
            elif [[ "$version" == "7.4" && "$ext" == "bcmath" ]]; then
                # Add json extension for PHP 7.4 (not needed in 8.0+)
                php_packages+=("php$version-$ext" "php$version-json")
            else
                php_packages+=("php$version-$ext")
            fi
        done
        
        # Install all packages for this PHP version
        for package in "${php_packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package "; then
                echo -e "${CYAN}     Installing $package...${RESET}"
                apt install -y "$package" || {
                    echo -e "${YELLOW}⚠️  Failed to install $package, continuing...${RESET}"
                }
            else
                echo -e "${GREEN}     ✅ $package already installed${RESET}"
            fi
        done
    done
    
    # Enable and start services
    echo -e "${CYAN}   Enabling and starting services...${RESET}"
    systemctl enable apache2
    systemctl enable mysql
    
    # Enable PHP-FPM services for all versions
    for version in "${php_versions[@]}"; do
        if systemctl list-unit-files | grep -q "php$version-fpm"; then
            echo -e "${CYAN}   Enabling PHP $version-FPM...${RESET}"
            systemctl enable php$version-fpm
            systemctl start php$version-fpm
        fi
    done
    
    systemctl start apache2
    systemctl start mysql
    
    # Enable Apache modules
    echo -e "${CYAN}   Enabling Apache modules...${RESET}"
    a2enmod rewrite
    a2enmod ssl
    a2enmod headers
    a2enmod proxy_fcgi
    a2enmod setenvif
    
    # Configure Apache for PHP-FPM
    echo -e "${CYAN}   Configuring Apache for PHP-FPM...${RESET}"
    for version in "${php_versions[@]}"; do
        if [ -f "/etc/apache2/conf-available/php$version-fpm.conf" ]; then
            a2enconf php$version-fpm
        fi
    done
    
    # Restart Apache to apply changes
    systemctl restart apache2
    
    echo -e "${GREEN}✅ Dependencies installed${RESET}"
}

# Create directories
create_directories() {
    echo -e "${CYAN}📁 Creating directories...${RESET}"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    
    # Create log directories
    mkdir -p "$LOG_DIR/php"
    chmod 755 "$LOG_DIR/php"
    chown root:adm "$LOG_DIR/php"
    
    # Create PHP-FPM pool directories for selected versions
    for version in "${php_versions[@]}"; do
        if [ -d "/etc/php/$version" ]; then
            mkdir -p "/etc/php/$version/fpm/pool.d"
            chmod 755 "/etc/php/$version/fpm/pool.d"
            chown root:root "/etc/php/$version/fpm/pool.d"
        fi
    done
    
    # Create SSL directory
    mkdir -p "/etc/ssl/websites"
    chmod 755 "/etc/ssl/websites"
    
    # Create backup directories
    mkdir -p "/root/website-config-backups"
    chmod 700 "/root/website-config-backups"
    
    mkdir -p "/root/website-deletion-backups"
    chmod 700 "/root/website-deletion-backups"
    
    mkdir -p "/root/php-switch-backups"
    chmod 700 "/root/php-switch-backups"
    
    # Create socket directory for PHP-FPM
    mkdir -p "/run/php"
    chmod 755 "/run/php"
    chown root:root "/run/php"
    
    echo -e "${GREEN}✅ Directories created${RESET}"
}

# Install scripts
install_scripts() {
    echo -e "${CYAN}📋 Installing scripts...${RESET}"
    
    # Get current directory
    CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # List of scripts to install
    scripts=(
        "toolkit.sh"
        "add-website.sh"
        "delete-website.sh"
        "enable-website.sh"
        "disable-website.sh"
        "website-info.sh"
        "switch-php.sh"
        "check-php-versions.sh"
        "backup-to-gdrive.sh"
    )
    
    # Copy scripts to installation directory
    for script in "${scripts[@]}"; do
        if [ -f "$CURRENT_DIR/$script" ]; then
            echo -e "${CYAN}   Installing $script...${RESET}"
            cp "$CURRENT_DIR/$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
        else
            echo -e "${YELLOW}⚠️  $script not found in current directory${RESET}"
        fi
    done
    
    # Create symlinks in /usr/local/bin
    echo -e "${CYAN}   Creating symlinks...${RESET}"
    ln -sf "$INSTALL_DIR/toolkit.sh" "$BIN_DIR/toolkit"
    ln -sf "$INSTALL_DIR/add-website.sh" "$BIN_DIR/add-website"
    ln -sf "$INSTALL_DIR/delete-website.sh" "$BIN_DIR/delete-website"
    ln -sf "$INSTALL_DIR/enable-website.sh" "$BIN_DIR/enable-website"
    ln -sf "$INSTALL_DIR/disable-website.sh" "$BIN_DIR/disable-website"
    ln -sf "$INSTALL_DIR/website-info.sh" "$BIN_DIR/website-info"
    ln -sf "$INSTALL_DIR/switch-php.sh" "$BIN_DIR/switch-php"
    ln -sf "$INSTALL_DIR/check-php-versions.sh" "$BIN_DIR/check-php"
    ln -sf "$INSTALL_DIR/backup-to-gdrive.sh" "$BIN_DIR/backup-gdrive"
    
    echo -e "${GREEN}✅ Scripts installed${RESET}"
}

# Create configuration files
create_config() {
    echo -e "${CYAN}⚙️  Creating configuration files...${RESET}"
    
    # Create toolkit config
    cat > "$CONFIG_DIR/toolkit.conf" << EOF
# Server Management Toolkit Configuration
# Generated on $(date)

# Installation directory
INSTALL_DIR="$INSTALL_DIR"

# Default PHP version
DEFAULT_PHP_VERSION="8.1"

# Backup settings
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESS_LEVEL=6

# SSL settings
SSL_DEFAULT_TYPE="letsencrypt"
SSL_CERT_DIR="/etc/ssl/websites"

# Log settings
LOG_RETENTION_DAYS=30
LOG_MAX_SIZE="100M"
EOF
    
    # Create logrotate configuration
    cat > "/etc/logrotate.d/server-management" << EOF
/var/log/toolkit.log
/var/log/website-management.log
/var/log/backup-gdrive.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

/var/log/php/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data adm
}
EOF
    
    echo -e "${GREEN}✅ Configuration files created${RESET}"
}

# Setup MySQL security
setup_mysql_security() {
    echo -e "${CYAN}🔒 Setting up MySQL security...${RESET}"
    
    # Check if MySQL is secured
    if mysql -u root -e "SELECT 1;" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  MySQL root user has no password${RESET}"
        echo -e "${YELLOW}   This is not recommended for production${RESET}"
        
        read -p "Do you want to secure MySQL installation? (Y/n): " secure_mysql
        if [[ ! "$secure_mysql" =~ ^[Nn]$ ]]; then
            echo -e "${CYAN}   Running mysql_secure_installation...${RESET}"
            mysql_secure_installation
        fi
    else
        echo -e "${GREEN}✅ MySQL appears to be secured${RESET}"
    fi
}

# Create desktop shortcuts (optional)
create_shortcuts() {
    echo -e "${CYAN}🖥️  Creating desktop shortcuts...${RESET}"
    
    # Create desktop file for toolkit
    cat > "/usr/share/applications/server-management-toolkit.desktop" << EOF
[Desktop Entry]
Name=Server Management Toolkit
Comment=Unified interface for server management
Exec=sudo toolkit
Icon=preferences-system
Terminal=true
Type=Application
Categories=System;Administration;
EOF
    
    echo -e "${GREEN}✅ Desktop shortcuts created${RESET}"
}

# Setup completion
setup_completion() {
    echo -e "${CYAN}📝 Setting up bash completion...${RESET}"
    
    # Create bash completion script
    cat > "/etc/bash_completion.d/toolkit" << 'EOF'
_toolkit_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="--add-website --delete-website --enable-website --disable-website --website-info --switch-php --check-php --backup --help --version"
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}
complete -F _toolkit_completion toolkit
EOF
    
    echo -e "${GREEN}✅ Bash completion setup${RESET}"
}

# Run tests
run_tests() {
    echo -e "${CYAN}🧪 Running installation tests...${RESET}"
    
    # Test toolkit command
    if command -v toolkit >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Toolkit command available${RESET}"
    else
        echo -e "${RED}❌ Toolkit command not found${RESET}"
        return 1
    fi
    
    # Test Apache
    if systemctl is-active --quiet apache2; then
        echo -e "${GREEN}✅ Apache is running${RESET}"
    else
        echo -e "${RED}❌ Apache is not running${RESET}"
        return 1
    fi
    
    # Test MySQL
    if systemctl is-active --quiet mysql; then
        echo -e "${GREEN}✅ MySQL is running${RESET}"
    else
        echo -e "${RED}❌ MySQL is not running${RESET}"
        return 1
    fi
    
    # Test PHP-FPM services for selected versions
    php_working=false
    
    for version in "${php_versions[@]}"; do
        if systemctl is-active --quiet php$version-fpm; then
            echo -e "${GREEN}✅ PHP $version-FPM is running${RESET}"
            php_working=true
        else
            echo -e "${YELLOW}⚠️  PHP $version-FPM is not running${RESET}"
        fi
    done
    
    if [ "$php_working" = false ]; then
        echo -e "${RED}❌ No PHP-FPM services are running${RESET}"
        return 1
    fi
    
    # Test PHP versions availability
    echo -e "${CYAN}   Testing PHP versions...${RESET}"
    for version in "${php_versions[@]}"; do
        if command -v php$version >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PHP $version command available${RESET}"
        else
            echo -e "${YELLOW}⚠️  PHP $version command not found${RESET}"
        fi
    done
    
    # Test PHP extensions
    echo -e "${CYAN}   Testing PHP extensions...${RESET}"
    required_extensions=("mysql" "curl" "gd" "mbstring" "xml" "zip" "bcmath" "intl")
    
    for version in "${php_versions[@]}"; do
        if command -v php$version >/dev/null 2>&1; then
            missing_extensions=()
            for ext in "${required_extensions[@]}"; do
                if ! php$version -m | grep -q "^$ext$"; then
                    missing_extensions+=("$ext")
                fi
            done
            
            if [ ${#missing_extensions[@]} -eq 0 ]; then
                echo -e "${GREEN}✅ PHP $version has all required extensions${RESET}"
            else
                echo -e "${YELLOW}⚠️  PHP $version missing extensions: ${missing_extensions[*]}${RESET}"
            fi
        fi
    done
    
    echo -e "${GREEN}✅ All tests completed${RESET}"
    return 0
}

# Show completion message
show_completion() {
    echo -e "${GREEN}🎉 Installation completed successfully!${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}📋 INSTALLATION SUMMARY:${RESET}"
    echo -e "${WHITE}• Scripts installed in: $INSTALL_DIR${RESET}"
    echo -e "${WHITE}• Commands available in: $BIN_DIR${RESET}"
    echo -e "${WHITE}• Configuration file: $CONFIG_DIR/toolkit.conf${RESET}"
    echo -e "${WHITE}• Log files: $LOG_DIR/toolkit.log${RESET}"
    echo
    echo -e "${BOLD}� PHP VERSIONS INSTALLED:${RESET}"
    php_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
    for version in "${php_versions[@]}"; do
        if command -v php$version >/dev/null 2>&1; then
            php_version_info=$(php$version --version | head -n1)
            echo -e "${WHITE}• $php_version_info${RESET}"
        else
            echo -e "${YELLOW}• PHP $version: Not installed${RESET}"
        fi
    done
    echo
    echo -e "${BOLD}�🚀 QUICK START:${RESET}"
    echo -e "${WHITE}• Run main toolkit: ${CYAN}sudo toolkit${RESET}"
    echo -e "${WHITE}• Add website: ${CYAN}sudo add-website${RESET}"
    echo -e "${WHITE}• Check website info: ${CYAN}sudo website-info${RESET}"
    echo -e "${WHITE}• Check PHP versions: ${CYAN}sudo check-php${RESET}"
    echo -e "${WHITE}• Backup to GDrive: ${CYAN}sudo backup-gdrive${RESET}"
    echo
    echo -e "${BOLD}📖 DOCUMENTATION:${RESET}"
    echo -e "${WHITE}• Help: ${CYAN}toolkit --help${RESET}"
    echo -e "${WHITE}• Version: ${CYAN}toolkit --version${RESET}"
    echo -e "${WHITE}• Repository: ${CYAN}https://github.com/ojifahru/manajemen-server${RESET}"
    echo
    echo -e "${BOLD}🔧 NEXT STEPS:${RESET}"
    echo -e "${WHITE}1. Run: ${CYAN}sudo toolkit${RESET}"
    echo -e "${WHITE}2. Setup backup: Choose backup configuration${RESET}"
    echo -e "${WHITE}3. Setup MySQL: Configure MySQL credentials${RESET}"
    echo -e "${WHITE}4. Create your first website: Choose add website${RESET}"
    echo -e "${WHITE}5. Test PHP versions: ${CYAN}sudo check-php${RESET}"
    echo -e "${WHITE}6. Manage PHP versions: ${CYAN}sudo manage-php${RESET}"
    echo
    echo -e "${BOLD}🔍 VERIFICATION:${RESET}"
    echo -e "${WHITE}• Check all services: ${CYAN}sudo toolkit --health-check${RESET}"
    echo -e "${WHITE}• View system status: ${CYAN}sudo systemctl status apache2 mysql${RESET}"
    echo -e "${WHITE}• Test PHP-FPM: ${CYAN}sudo systemctl status php*-fpm${RESET}"
    echo
    echo -e "${YELLOW}⚠️  IMPORTANT NOTES:${RESET}"
    echo -e "${YELLOW}• Remember to secure your MySQL installation${RESET}"
    echo -e "${YELLOW}• Setup firewall rules for production use${RESET}"
    echo -e "${YELLOW}• Configure SSL certificates for websites${RESET}"
    echo -e "${YELLOW}• Test all PHP versions before creating websites${RESET}"
    echo
}

# Show PHP repository information
show_repository_info() {
    echo -e "${CYAN}📦 PHP Repository Information${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        echo -e "${WHITE}• Primary Repository: Ondrej Surý's PPA${RESET}"
        echo -e "${WHITE}• Repository URL: ppa:ondrej/php${RESET}"
        echo -e "${WHITE}• Supports: Ubuntu 18.04+, Debian 9+${RESET}"
        echo -e "${WHITE}• Provides: PHP 7.4, 8.0, 8.1, 8.2, 8.3 with all extensions${RESET}"
        echo -e "${WHITE}• Maintainer: Ondrej Surý (Debian PHP maintainer)${RESET}"
        echo -e "${WHITE}• Official: Yes - Recommended by PHP.net${RESET}"
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
        echo -e "${WHITE}• Primary Repository: Remi's RPM Repository${RESET}"
        echo -e "${WHITE}• Repository URL: https://rpms.remirepo.net/${RESET}"
        echo -e "${WHITE}• Supports: CentOS 7+, RHEL 7+, Fedora${RESET}"
        echo -e "${WHITE}• Provides: Multiple PHP versions with extensions${RESET}"
        echo -e "${WHITE}• Maintainer: Remi Collet${RESET}"
        echo -e "${WHITE}• Official: Widely trusted third-party repository${RESET}"
    else
        echo -e "${YELLOW}• System: $OS (using default repositories)${RESET}"
        echo -e "${YELLOW}• Note: May have limited PHP versions available${RESET}"
    fi
    echo
}

# Add PPA with error handling
add_ondrej_ppa() {
    echo -e "${CYAN}   Adding Ondrej's PPA for multiple PHP versions...${RESET}"
    
    # Check if PPA is already added
    if grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo -e "${GREEN}   ✅ Ondrej's PPA already added${RESET}"
        return 0
    fi
    
    # Try to add PPA
    if add-apt-repository ppa:ondrej/php -y; then
        echo -e "${GREEN}   ✅ Ondrej's PPA added successfully${RESET}"
        apt update -qq
        return 0
    else
        echo -e "${RED}   ❌ Failed to add Ondrej's PPA${RESET}"
        echo -e "${YELLOW}   ⚠️  Will try to install available PHP versions from default repository${RESET}"
        return 1
    fi
}

# Interactive PHP version selection
select_php_versions() {
    show_repository_info
    
    echo -e "${CYAN}🐘 PHP Version Selection${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}Choose PHP installation method:${RESET}"
    echo -e "${WHITE}1. Install all PHP versions (7.4, 8.0, 8.1, 8.2, 8.3) - Recommended for development${RESET}"
    echo -e "${WHITE}2. Install specific PHP versions - Recommended for production${RESET}"
    echo -e "${WHITE}3. Install only latest stable (PHP 8.2) - Minimal installation${RESET}"
    echo
    
    read -p "Select option (1-3): " php_choice
    
    case $php_choice in
        1)
            echo -e "${GREEN}✅ Installing all PHP versions${RESET}"
            php_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
            ;;
        2)
            echo -e "${CYAN}Available PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3${RESET}"
            echo -e "${YELLOW}Enter versions separated by space (e.g., 8.1 8.2):${RESET}"
            read -p "PHP versions: " user_versions
            php_versions=($user_versions)
            
            # Validate versions
            valid_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
            for version in "${php_versions[@]}"; do
                if [[ ! " ${valid_versions[@]} " =~ " ${version} " ]]; then
                    echo -e "${RED}❌ Invalid PHP version: $version${RESET}"
                    echo -e "${YELLOW}Available versions: ${valid_versions[*]}${RESET}"
                    exit 1
                fi
            done
            ;;
        3)
            echo -e "${GREEN}✅ Installing PHP 8.2 only${RESET}"
            php_versions=("8.2")
            ;;
        *)
            echo -e "${RED}❌ Invalid option${RESET}"
            exit 1
            ;;
    esac
    
    echo -e "${CYAN}Selected PHP versions: ${php_versions[*]}${RESET}"
    echo
}

# Show resource estimation
show_resource_estimation() {
    echo -e "${CYAN}📊 Resource Estimation${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    # Calculate estimated disk usage
    php_count=${#php_versions[@]}
    estimated_disk=$((php_count * 150)) # ~150MB per PHP version
    estimated_memory=$((php_count * 50)) # ~50MB per PHP-FPM service
    
    echo -e "${WHITE}PHP versions to install: ${php_versions[*]}${RESET}"
    echo -e "${WHITE}Estimated disk usage: ~${estimated_disk}MB${RESET}"
    echo -e "${WHITE}Estimated memory usage: ~${estimated_memory}MB${RESET}"
    echo
    
    if [ $php_count -gt 3 ]; then
        echo -e "${YELLOW}⚠️  Installing many PHP versions will use more resources${RESET}"
        echo -e "${YELLOW}   Consider using fewer versions for production servers${RESET}"
        echo
    fi
}

# Create PHP management script
create_php_manager() {
    echo -e "${CYAN}📋 Creating PHP management script...${RESET}"
    
    cat > "$INSTALL_DIR/manage-php.sh" << 'EOF'
#!/bin/bash
# PHP Version Manager
# Add or remove PHP versions after installation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

show_installed_php() {
    echo -e "${CYAN}📋 Installed PHP Versions:${RESET}"
    for version in 7.4 8.0 8.1 8.2 8.3; do
        if command -v php$version >/dev/null 2>&1; then
            status=$(systemctl is-active php$version-fpm 2>/dev/null || echo "not-found")
            echo -e "${GREEN}✅ PHP $version - Status: $status${RESET}"
        else
            echo -e "${YELLOW}❌ PHP $version - Not installed${RESET}"
        fi
    done
}

install_php_version() {
    local version=$1
    echo -e "${CYAN}Installing PHP $version...${RESET}"
    
    # Add PPA if not exists
    if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        add-apt-repository ppa:ondrej/php -y
        apt update
    fi
    
    # Install PHP and extensions
    extensions=("fpm" "mysql" "curl" "gd" "mbstring" "xml" "zip" "bcmath" "intl" "opcache")
    for ext in "${extensions[@]}"; do
        apt install -y php$version-$ext
    done
    
    # Enable and start service
    systemctl enable php$version-fpm
    systemctl start php$version-fpm
    
    # Configure Apache
    if [ -f "/etc/apache2/conf-available/php$version-fpm.conf" ]; then
        a2enconf php$version-fpm
        systemctl reload apache2
    fi
    
    echo -e "${GREEN}✅ PHP $version installed successfully${RESET}"
}

case "${1:-menu}" in
    "list")
        show_installed_php
        ;;
    "install")
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 install <version>${RESET}"
            exit 1
        fi
        install_php_version "$2"
        ;;
    "menu"|*)
        echo -e "${CYAN}PHP Version Manager${RESET}"
        echo "1. List installed versions"
        echo "2. Install new version"
        echo "3. Exit"
        read -p "Choose option: " choice
        
        case $choice in
            1) show_installed_php ;;
            2) 
                echo "Available versions: 7.4, 8.0, 8.1, 8.2, 8.3"
                read -p "Enter version to install: " version
                install_php_version "$version"
                ;;
            3) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/manage-php.sh"
    ln -sf "$INSTALL_DIR/manage-php.sh" "$BIN_DIR/manage-php"
    
    echo -e "${GREEN}✅ PHP management script created${RESET}"
}

# Main installation function
main() {
    show_header
    
    echo -e "${BOLD}🚀 Starting Server Management Toolkit Installation${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Check requirements
    check_requirements
    
    # Show repository information
    show_repository_info
    
    # Select PHP versions to install
    select_php_versions
    
    # Show resource estimation
    show_resource_estimation
    
    # Confirm installation
    echo -e "${YELLOW}This will install Server Management Toolkit on your system.${RESET}"
    echo -e "${YELLOW}The following will be installed:${RESET}"
    echo -e "${WHITE}• Apache2, MySQL, PHP-FPM${RESET}"
    echo -e "${WHITE}• Certbot for SSL certificates${RESET}"
    echo -e "${WHITE}• Rclone for Google Drive backup${RESET}"
    echo -e "${WHITE}• Server management scripts${RESET}"
    echo
    read -p "Continue with installation? (Y/n): " confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${RESET}"
        exit 0
    fi
    
    # Installation steps
    echo -e "${CYAN}Starting installation...${RESET}"
    
    add_ondrej_ppa
    install_dependencies
    create_directories
    install_scripts
    create_php_manager
    create_config
    setup_mysql_security
    create_shortcuts
    setup_completion
    
    # Show resource estimation
    show_resource_estimation
    
    # Run tests
    if run_tests; then
        show_completion
    else
        echo -e "${RED}❌ Installation completed but some tests failed${RESET}"
        echo -e "${YELLOW}Please check the system status manually${RESET}"
    fi
}

# Run main function
main "$@"
