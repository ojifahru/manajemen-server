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
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}${BOLD}            SERVER MANAGEMENT TOOLKIT INSTALLER              ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Version: 1.0                                               ${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Author: Server Management Team                            ${RESET} ${CYAN}║${RESET}"
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
    
    # Install required packages
    packages=(
        "apache2"
        "mysql-server"
        "php-fpm"
        "php8.1-fpm"
        "php8.2-fpm"
        "curl"
        "wget"
        "openssl"
        "certbot"
        "python3-certbot-apache"
        "rclone"
        "bc"
        "jq"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo -e "${CYAN}   Installing $package...${RESET}"
            apt install -y "$package" || {
                echo -e "${YELLOW}⚠️  Failed to install $package, continuing...${RESET}"
            }
        else
            echo -e "${GREEN}   ✅ $package already installed${RESET}"
        fi
    done
    
    # Enable and start services
    echo -e "${CYAN}   Enabling services...${RESET}"
    systemctl enable apache2
    systemctl enable mysql
    systemctl enable php8.1-fpm
    systemctl enable php8.2-fpm
    
    systemctl start apache2
    systemctl start mysql
    systemctl start php8.1-fpm
    systemctl start php8.2-fpm
    
    # Enable Apache modules
    echo -e "${CYAN}   Enabling Apache modules...${RESET}"
    a2enmod rewrite
    a2enmod ssl
    a2enmod headers
    a2enmod proxy_fcgi
    a2enmod setenvif
    
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
    
    # Test PHP-FPM
    if systemctl is-active --quiet php8.1-fpm; then
        echo -e "${GREEN}✅ PHP-FPM is running${RESET}"
    else
        echo -e "${RED}❌ PHP-FPM is not running${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All tests passed${RESET}"
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
    echo -e "${BOLD}🚀 QUICK START:${RESET}"
    echo -e "${WHITE}• Run main toolkit: ${CYAN}sudo toolkit${RESET}"
    echo -e "${WHITE}• Add website: ${CYAN}sudo add-website${RESET}"
    echo -e "${WHITE}• Check website info: ${CYAN}sudo website-info${RESET}"
    echo -e "${WHITE}• Backup to GDrive: ${CYAN}sudo backup-gdrive${RESET}"
    echo
    echo -e "${BOLD}📖 DOCUMENTATION:${RESET}"
    echo -e "${WHITE}• Help: ${CYAN}toolkit --help${RESET}"
    echo -e "${WHITE}• Version: ${CYAN}toolkit --version${RESET}"
    echo -e "${WHITE}• README: Check project repository${RESET}"
    echo
    echo -e "${BOLD}🔧 NEXT STEPS:${RESET}"
    echo -e "${WHITE}1. Run: ${CYAN}sudo toolkit${RESET}"
    echo -e "${WHITE}2. Setup backup: Choose option 9${RESET}"
    echo -e "${WHITE}3. Setup MySQL: Choose option 10${RESET}"
    echo -e "${WHITE}4. Create your first website: Choose option 1${RESET}"
    echo
    echo -e "${YELLOW}⚠️  IMPORTANT: Remember to secure your MySQL installation${RESET}"
    echo -e "${YELLOW}   and setup firewall rules for production use${RESET}"
    echo
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
    
    install_dependencies
    create_directories
    install_scripts
    create_config
    setup_mysql_security
    create_shortcuts
    setup_completion
    
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
