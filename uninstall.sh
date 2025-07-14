#!/bin/bash

# Server Management Toolkit Uninstaller
# Remove toolkit and clean up system
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
CONFIG_DIR="/etc"

# Display header
show_header() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET}${BOLD}           SERVER MANAGEMENT TOOLKIT UNINSTALLER             ${RESET}${RED}║${RESET}"
    echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}Version: 1.0                                               ${RESET} ${RED}║${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}Date: $(date '+%Y-%m-%d %H:%M:%S')                                   ${RESET} ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Uninstaller harus dijalankan sebagai root${RESET}"
        echo -e "${YELLOW}   Gunakan: sudo $0${RESET}"
        exit 1
    fi
}

# Show what will be removed
show_removal_list() {
    echo -e "${BOLD}🗑️  ITEMS TO BE REMOVED:${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}• Installation directory: $INSTALL_DIR${RESET}"
    echo -e "${WHITE}• Binary symlinks in: $BIN_DIR${RESET}"
    echo -e "${WHITE}• Configuration files: $CONFIG_DIR/toolkit.conf${RESET}"
    echo -e "${WHITE}• Logrotate configuration${RESET}"
    echo -e "${WHITE}• Desktop shortcuts${RESET}"
    echo -e "${WHITE}• Bash completion${RESET}"
    echo
    echo -e "${BOLD}⚠️  ITEMS THAT WILL BE KEPT:${RESET}"
    echo -e "${WHITE}• Apache2, MySQL, PHP-FPM (system packages)${RESET}"
    echo -e "${WHITE}• Website files and databases${RESET}"
    echo -e "${WHITE}• SSL certificates${RESET}"
    echo -e "${WHITE}• Log files${RESET}"
    echo -e "${WHITE}• Backup files${RESET}"
    echo
}

# Confirm uninstallation
confirm_uninstall() {
    echo -e "${RED}⚠️  WARNING: This will remove Server Management Toolkit${RESET}"
    echo -e "${RED}   Your websites and data will NOT be affected${RESET}"
    echo
    echo -e "${YELLOW}Are you sure you want to proceed?${RESET}"
    read -p "Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${GREEN}Uninstallation cancelled${RESET}"
        exit 0
    fi
}

# Remove scripts and binaries
remove_scripts() {
    echo -e "${CYAN}🗑️  Removing scripts and binaries...${RESET}"
    
    # Remove symlinks
    scripts=(
        "toolkit"
        "add-website"
        "delete-website"
        "enable-website"
        "disable-website"
        "website-info"
        "switch-php"
        "check-php"
        "backup-gdrive"
    )
    
    for script in "${scripts[@]}"; do
        if [ -L "$BIN_DIR/$script" ]; then
            echo -e "${CYAN}   Removing $BIN_DIR/$script${RESET}"
            rm -f "$BIN_DIR/$script"
        fi
    done
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${CYAN}   Removing $INSTALL_DIR${RESET}"
        rm -rf "$INSTALL_DIR"
    fi
    
    echo -e "${GREEN}✅ Scripts and binaries removed${RESET}"
}

# Remove configuration files
remove_config() {
    echo -e "${CYAN}🗑️  Removing configuration files...${RESET}"
    
    # Remove toolkit config
    if [ -f "$CONFIG_DIR/toolkit.conf" ]; then
        echo -e "${CYAN}   Removing $CONFIG_DIR/toolkit.conf${RESET}"
        rm -f "$CONFIG_DIR/toolkit.conf"
    fi
    
    # Remove logrotate config
    if [ -f "/etc/logrotate.d/server-management" ]; then
        echo -e "${CYAN}   Removing /etc/logrotate.d/server-management${RESET}"
        rm -f "/etc/logrotate.d/server-management"
    fi
    
    # Remove bash completion
    if [ -f "/etc/bash_completion.d/toolkit" ]; then
        echo -e "${CYAN}   Removing /etc/bash_completion.d/toolkit${RESET}"
        rm -f "/etc/bash_completion.d/toolkit"
    fi
    
    # Remove desktop shortcut
    if [ -f "/usr/share/applications/server-management-toolkit.desktop" ]; then
        echo -e "${CYAN}   Removing desktop shortcut${RESET}"
        rm -f "/usr/share/applications/server-management-toolkit.desktop"
    fi
    
    echo -e "${GREEN}✅ Configuration files removed${RESET}"
}

# Optional: Remove packages
remove_packages() {
    echo -e "${YELLOW}Do you want to remove installed packages?${RESET}"
    echo -e "${YELLOW}This will remove Apache2, MySQL, PHP-FPM, etc.${RESET}"
    echo -e "${RED}⚠️  This will affect your websites!${RESET}"
    read -p "Remove packages? (y/N): " remove_pkgs
    
    if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}🗑️  Removing packages...${RESET}"
        
        packages=(
            "certbot"
            "python3-certbot-apache"
            "rclone"
        )
        
        for package in "${packages[@]}"; do
            if dpkg -l | grep -q "^ii  $package "; then
                echo -e "${CYAN}   Removing $package${RESET}"
                apt remove -y "$package"
            fi
        done
        
        echo -e "${YELLOW}⚠️  Core packages (Apache, MySQL, PHP) were not removed${RESET}"
        echo -e "${YELLOW}   Remove them manually if needed${RESET}"
    fi
}

# Clean up logs (optional)
clean_logs() {
    echo -e "${YELLOW}Do you want to clean up toolkit logs?${RESET}"
    read -p "Clean logs? (y/N): " clean_logs
    
    if [[ "$clean_logs" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}🗑️  Cleaning up logs...${RESET}"
        
        # Remove toolkit logs
        rm -f /var/log/toolkit.log*
        rm -f /var/log/website-management.log*
        rm -f /var/log/backup-gdrive.log*
        
        echo -e "${GREEN}✅ Logs cleaned${RESET}"
    fi
}

# Clean up backup directories (optional)
clean_backups() {
    echo -e "${YELLOW}Do you want to clean up backup directories?${RESET}"
    echo -e "${RED}⚠️  This will remove configuration backups!${RESET}"
    read -p "Clean backups? (y/N): " clean_backups
    
    if [[ "$clean_backups" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}🗑️  Cleaning up backups...${RESET}"
        
        # Remove backup directories
        rm -rf /root/website-config-backups
        rm -rf /root/website-deletion-backups
        rm -rf /root/php-switch-backups
        
        echo -e "${GREEN}✅ Backups cleaned${RESET}"
    fi
}

# Show completion message
show_completion() {
    echo -e "${GREEN}🎉 Uninstallation completed!${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}📋 UNINSTALLATION SUMMARY:${RESET}"
    echo -e "${WHITE}• Scripts removed from: $INSTALL_DIR${RESET}"
    echo -e "${WHITE}• Symlinks removed from: $BIN_DIR${RESET}"
    echo -e "${WHITE}• Configuration files removed${RESET}"
    echo -e "${WHITE}• System cleanup completed${RESET}"
    echo
    echo -e "${BOLD}✅ WHAT'S STILL THERE:${RESET}"
    echo -e "${WHITE}• Your websites and files${RESET}"
    echo -e "${WHITE}• Apache2, MySQL, PHP-FPM${RESET}"
    echo -e "${WHITE}• SSL certificates${RESET}"
    echo -e "${WHITE}• Database data${RESET}"
    echo
    echo -e "${BOLD}🔧 MANUAL CLEANUP (if needed):${RESET}"
    echo -e "${WHITE}• Remove packages: apt remove apache2 mysql-server php-fpm${RESET}"
    echo -e "${WHITE}• Remove websites: rm -rf /etc/apache2/sites-*${RESET}"
    echo -e "${WHITE}• Remove SSL certs: rm -rf /etc/ssl/websites${RESET}"
    echo
    echo -e "${YELLOW}Thank you for using Server Management Toolkit!${RESET}"
}

# Main uninstallation function
main() {
    show_header
    
    echo -e "${BOLD}🗑️  Server Management Toolkit Uninstaller${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    # Check if running as root
    check_root
    
    # Check if toolkit is installed
    if [ ! -d "$INSTALL_DIR" ] && [ ! -L "$BIN_DIR/toolkit" ]; then
        echo -e "${YELLOW}⚠️  Toolkit doesn't appear to be installed${RESET}"
        echo -e "${YELLOW}   Nothing to uninstall${RESET}"
        exit 0
    fi
    
    # Show what will be removed
    show_removal_list
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Uninstallation steps
    echo -e "${CYAN}Starting uninstallation...${RESET}"
    echo
    
    remove_scripts
    remove_config
    remove_packages
    clean_logs
    clean_backups
    
    # Show completion
    show_completion
}

# Run main function
main "$@"
