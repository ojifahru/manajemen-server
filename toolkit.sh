#!/bin/bash

# Server Management Toolkit
# Unified interface for all server management scripts
# Version: 1.0
# Author: Server Management Team

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/toolkit.log"
CONFIG_FILE="/etc/toolkit.conf"

# Script paths
ADD_WEBSITE_SCRIPT="$SCRIPT_DIR/add-website.sh"
DELETE_WEBSITE_SCRIPT="$SCRIPT_DIR/delete-website.sh"
ENABLE_WEBSITE_SCRIPT="$SCRIPT_DIR/enable-website.sh"
DISABLE_WEBSITE_SCRIPT="$SCRIPT_DIR/disable-website.sh"
WEBSITE_INFO_SCRIPT="$SCRIPT_DIR/website-info.sh"
SWITCH_PHP_SCRIPT="$SCRIPT_DIR/switch-php.sh"
CHECK_PHP_SCRIPT="$SCRIPT_DIR/check-php-versions.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-to-gdrive.sh"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TOOLKIT: $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Toolkit harus dijalankan sebagai root${RESET}"
        echo -e "${YELLOW}   Gunakan: sudo $0${RESET}"
        exit 1
    fi
}

# Display header
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}${BOLD}                 SERVER MANAGEMENT TOOLKIT                   ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Version: 1.0                    Author: Server Management${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}Date: $(date '+%Y-%m-%d %H:%M:%S')           System: $(uname -n)${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Display system status
show_system_status() {
    echo -e "${BOLD}🖥️  SYSTEM STATUS${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    # Apache Status
    if systemctl is-active --quiet apache2; then
        echo -e "${GREEN}✅ Apache2       : Running${RESET}"
    else
        echo -e "${RED}❌ Apache2       : Stopped${RESET}"
    fi
    
    # MySQL Status
    if systemctl is-active --quiet mysql; then
        echo -e "${GREEN}✅ MySQL         : Running${RESET}"
    else
        echo -e "${RED}❌ MySQL         : Stopped${RESET}"
    fi
    
    # PHP-FPM Status
    php_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
    php_running=0
    for version in "${php_versions[@]}"; do
        if systemctl is-active --quiet php$version-fpm 2>/dev/null; then
            echo -e "${GREEN}✅ PHP $version-FPM  : Running${RESET}"
            ((php_running++))
        fi
    done
    
    if [ $php_running -eq 0 ]; then
        echo -e "${RED}❌ PHP-FPM      : No versions running${RESET}"
    fi
    
    # Disk Usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        echo -e "${RED}⚠️  Disk Usage   : ${disk_usage}% (Critical)${RESET}"
    elif [ "$disk_usage" -gt 80 ]; then
        echo -e "${YELLOW}⚠️  Disk Usage   : ${disk_usage}% (Warning)${RESET}"
    else
        echo -e "${GREEN}✅ Disk Usage   : ${disk_usage}% (OK)${RESET}"
    fi
    
    # Memory Usage
    memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        echo -e "${RED}⚠️  Memory Usage : ${memory_usage}% (Critical)${RESET}"
    elif (( $(echo "$memory_usage > 80" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Memory Usage : ${memory_usage}% (Warning)${RESET}"
    else
        echo -e "${GREEN}✅ Memory Usage : ${memory_usage}% (OK)${RESET}"
    fi
    
    # Load Average
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    echo -e "${CYAN}📊 Load Average : $load_avg${RESET}"
    
    # Website Count
    website_count=$(find /etc/apache2/sites-enabled -name "*.conf" -not -name "000-default.conf" -not -name "default-ssl.conf" 2>/dev/null | wc -l)
    echo -e "${CYAN}🌐 Active Sites : $website_count${RESET}"
    
    echo
}

# Main menu
show_main_menu() {
    echo -e "${BOLD}🚀 PILIH OPERASI${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}[1]${RESET} ${GREEN}Tambah Website Baru${RESET}          ${CYAN}[add-website.sh]${RESET}"
    echo -e "${WHITE}[2]${RESET} ${YELLOW}Hapus Website${RESET}                ${CYAN}[delete-website.sh]${RESET}"
    echo -e "${WHITE}[3]${RESET} ${BLUE}Aktifkan Website${RESET}             ${CYAN}[enable-website.sh]${RESET}"
    echo -e "${WHITE}[4]${RESET} ${MAGENTA}Nonaktifkan Website${RESET}          ${CYAN}[disable-website.sh]${RESET}"
    echo -e "${WHITE}[5]${RESET} ${CYAN}Informasi Website${RESET}            ${CYAN}[website-info.sh]${RESET}"
    echo -e "${WHITE}[6]${RESET} ${YELLOW}Switch PHP Version${RESET}           ${CYAN}[switch-php.sh]${RESET}"
    echo -e "${WHITE}[7]${RESET} ${GREEN}Cek Status PHP${RESET}               ${CYAN}[check-php-versions.sh]${RESET}"
    echo -e "${WHITE}[8]${RESET} ${BLUE}Backup ke Google Drive${RESET}       ${CYAN}[backup-to-gdrive.sh]${RESET}"
    echo
    echo -e "${BOLD}🔧 UTILITAS${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}[9]${RESET} ${CYAN}Setup Backup Google Drive${RESET}"
    echo -e "${WHITE}[10]${RESET} ${CYAN}Setup MySQL Credentials${RESET}"
    echo -e "${WHITE}[11]${RESET} ${CYAN}System Health Check${RESET}"
    echo -e "${WHITE}[12]${RESET} ${CYAN}View Logs${RESET}"
    echo -e "${WHITE}[13]${RESET} ${CYAN}Bulk Operations${RESET}"
    echo
    echo -e "${BOLD}📋 LAINNYA${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}[h]${RESET} ${WHITE}Help & Documentation${RESET}"
    echo -e "${WHITE}[q]${RESET} ${WHITE}Quit${RESET}"
    echo
}

# Execute script with error handling
execute_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}❌ Script tidak ditemukan: $script_path${RESET}"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}⚠️  Script tidak executable, memberikan permission...${RESET}"
        chmod +x "$script_path"
    fi
    
    echo -e "${CYAN}🚀 Menjalankan: $script_name${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    log_action "Executing $script_name"
    
    # Execute script
    if "$script_path" "${@:3}"; then
        log_action "$script_name executed successfully"
        echo -e "${GREEN}✅ $script_name selesai dengan sukses${RESET}"
    else
        log_action "ERROR: $script_name failed"
        echo -e "${RED}❌ $script_name gagal dijalankan${RESET}"
        return 1
    fi
}

# Setup backup
setup_backup() {
    echo -e "${CYAN}🔧 Setup Backup Google Drive${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    if [ -f "$BACKUP_SCRIPT" ]; then
        execute_script "$BACKUP_SCRIPT" "Backup Setup" --setup
    else
        echo -e "${RED}❌ Backup script tidak ditemukan${RESET}"
    fi
}

# Setup MySQL
setup_mysql() {
    echo -e "${CYAN}🔧 Setup MySQL Credentials${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    if [ -f "$BACKUP_SCRIPT" ]; then
        execute_script "$BACKUP_SCRIPT" "MySQL Setup" --setup-mysql
    else
        echo -e "${RED}❌ Backup script tidak ditemukan${RESET}"
    fi
}

# System health check
system_health_check() {
    echo -e "${CYAN}🏥 System Health Check${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    # Check disk space
    echo -e "${BOLD}📊 Disk Space Check:${RESET}"
    df -h | grep -E "^/dev" | awk '{print $1 " " $5 " " $6}' | while read line; do
        usage=$(echo $line | awk '{print $2}' | sed 's/%//')
        if [ "$usage" -gt 90 ]; then
            echo -e "${RED}  ❌ $line (Critical)${RESET}"
        elif [ "$usage" -gt 80 ]; then
            echo -e "${YELLOW}  ⚠️  $line (Warning)${RESET}"
        else
            echo -e "${GREEN}  ✅ $line (OK)${RESET}"
        fi
    done
    
    echo
    echo -e "${BOLD}🔧 Service Status:${RESET}"
    services=("apache2" "mysql" "php8.1-fpm" "php8.2-fpm")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}  ✅ $service: Running${RESET}"
        else
            echo -e "${RED}  ❌ $service: Stopped${RESET}"
        fi
    done
    
    echo
    echo -e "${BOLD}🌐 Website Status:${RESET}"
    if [ -f "$WEBSITE_INFO_SCRIPT" ]; then
        "$WEBSITE_INFO_SCRIPT" -s 2>/dev/null || echo -e "${YELLOW}  ⚠️  Website info script tidak dapat dijalankan${RESET}"
    else
        echo -e "${YELLOW}  ⚠️  Website info script tidak ditemukan${RESET}"
    fi
    
    echo
    echo -e "${BOLD}🔍 Log Errors (Last 10):${RESET}"
    if [ -f "/var/log/apache2/error.log" ]; then
        tail -10 /var/log/apache2/error.log | grep -i error | head -5 | while read line; do
            echo -e "${RED}  ❌ $line${RESET}"
        done
    fi
}

# View logs
view_logs() {
    echo -e "${CYAN}📋 View Logs${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    echo -e "${WHITE}Pilih log yang ingin dilihat:${RESET}"
    echo -e "${WHITE}[1]${RESET} Apache Error Log"
    echo -e "${WHITE}[2]${RESET} Apache Access Log"
    echo -e "${WHITE}[3]${RESET} MySQL Error Log"
    echo -e "${WHITE}[4]${RESET} PHP-FPM Log"
    echo -e "${WHITE}[5]${RESET} Toolkit Log"
    echo -e "${WHITE}[6]${RESET} Website Management Log"
    echo -e "${WHITE}[7]${RESET} Backup Log"
    echo -e "${WHITE}[b]${RESET} Back to main menu"
    echo
    
    read -p "Pilih opsi: " log_choice
    
    case $log_choice in
        1)
            echo -e "${CYAN}📄 Apache Error Log (Last 50 lines):${RESET}"
            tail -50 /var/log/apache2/error.log 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        2)
            echo -e "${CYAN}📄 Apache Access Log (Last 50 lines):${RESET}"
            tail -50 /var/log/apache2/access.log 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        3)
            echo -e "${CYAN}📄 MySQL Error Log (Last 50 lines):${RESET}"
            tail -50 /var/log/mysql/error.log 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        4)
            echo -e "${CYAN}📄 PHP-FPM Log (Last 50 lines):${RESET}"
            find /var/log/php/ -name "*.log" -exec tail -10 {} \; 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        5)
            echo -e "${CYAN}📄 Toolkit Log (Last 50 lines):${RESET}"
            tail -50 "$LOG_FILE" 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        6)
            echo -e "${CYAN}📄 Website Management Log (Last 50 lines):${RESET}"
            tail -50 /var/log/website-management.log 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        7)
            echo -e "${CYAN}📄 Backup Log (Last 50 lines):${RESET}"
            tail -50 /var/log/backup-gdrive.log 2>/dev/null || echo "Log tidak ditemukan"
            ;;
        b)
            return
            ;;
        *)
            echo -e "${RED}❌ Pilihan tidak valid${RESET}"
            ;;
    esac
}

# Bulk operations
bulk_operations() {
    echo -e "${CYAN}🔄 Bulk Operations${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    echo -e "${WHITE}Pilih operasi bulk:${RESET}"
    echo -e "${WHITE}[1]${RESET} Backup semua website"
    echo -e "${WHITE}[2]${RESET} Restart semua PHP-FPM"
    echo -e "${WHITE}[3]${RESET} Cek status semua website"
    echo -e "${WHITE}[4]${RESET} Update semua SSL certificates"
    echo -e "${WHITE}[5]${RESET} Disable semua website"
    echo -e "${WHITE}[6]${RESET} Enable semua website"
    echo -e "${WHITE}[b]${RESET} Back to main menu"
    echo
    
    read -p "Pilih opsi: " bulk_choice
    
    case $bulk_choice in
        1)
            echo -e "${CYAN}🔄 Backup semua website...${RESET}"
            if [ -f "$BACKUP_SCRIPT" ]; then
                execute_script "$BACKUP_SCRIPT" "Bulk Backup"
            else
                echo -e "${RED}❌ Backup script tidak ditemukan${RESET}"
            fi
            ;;
        2)
            echo -e "${CYAN}🔄 Restart semua PHP-FPM...${RESET}"
            for version in 7.4 8.0 8.1 8.2 8.3; do
                if systemctl is-active --quiet php$version-fpm 2>/dev/null; then
                    echo -e "${CYAN}Restarting PHP $version-FPM...${RESET}"
                    systemctl restart php$version-fpm
                    echo -e "${GREEN}✅ PHP $version-FPM restarted${RESET}"
                fi
            done
            ;;
        3)
            echo -e "${CYAN}🔄 Cek status semua website...${RESET}"
            if [ -f "$WEBSITE_INFO_SCRIPT" ]; then
                execute_script "$WEBSITE_INFO_SCRIPT" "Website Status Check" -s
            else
                echo -e "${RED}❌ Website info script tidak ditemukan${RESET}"
            fi
            ;;
        4)
            echo -e "${CYAN}🔄 Update semua SSL certificates...${RESET}"
            if command -v certbot >/dev/null 2>&1; then
                certbot renew --quiet
                echo -e "${GREEN}✅ SSL certificates updated${RESET}"
            else
                echo -e "${RED}❌ Certbot tidak ditemukan${RESET}"
            fi
            ;;
        5)
            echo -e "${CYAN}🔄 Disable semua website...${RESET}"
            echo -e "${RED}⚠️  Ini akan menonaktifkan semua website!${RESET}"
            read -p "Apakah Anda yakin? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                for site in /etc/apache2/sites-enabled/*.conf; do
                    if [ -f "$site" ]; then
                        sitename=$(basename "$site")
                        echo -e "${YELLOW}Disabling $sitename...${RESET}"
                        a2dissite "$sitename"
                    fi
                done
                systemctl reload apache2
                echo -e "${GREEN}✅ Semua website dinonaktifkan${RESET}"
            fi
            ;;
        6)
            echo -e "${CYAN}🔄 Enable semua website...${RESET}"
            for site in /etc/apache2/sites-available/*.conf; do
                if [ -f "$site" ]; then
                    sitename=$(basename "$site")
                    if [[ "$sitename" != "000-default.conf" && "$sitename" != "default-ssl.conf" ]]; then
                        echo -e "${GREEN}Enabling $sitename...${RESET}"
                        a2ensite "$sitename"
                    fi
                fi
            done
            systemctl reload apache2
            echo -e "${GREEN}✅ Semua website diaktifkan${RESET}"
            ;;
        b)
            return
            ;;
        *)
            echo -e "${RED}❌ Pilihan tidak valid${RESET}"
            ;;
    esac
}

# Show help
show_help() {
    echo -e "${CYAN}📖 Help & Documentation${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    
    echo -e "${BOLD}🚀 QUICK START:${RESET}"
    echo -e "${WHITE}1. Jalankan toolkit dengan: sudo ./toolkit.sh${RESET}"
    echo -e "${WHITE}2. Pilih operasi dari menu utama${RESET}"
    echo -e "${WHITE}3. Ikuti instruksi yang muncul${RESET}"
    echo
    
    echo -e "${BOLD}📋 SCRIPT DESCRIPTIONS:${RESET}"
    echo -e "${WHITE}• add-website.sh     : Membuat website baru dengan SSL${RESET}"
    echo -e "${WHITE}• delete-website.sh  : Menghapus website dengan backup${RESET}"
    echo -e "${WHITE}• enable-website.sh  : Mengaktifkan website${RESET}"
    echo -e "${WHITE}• disable-website.sh : Menonaktifkan website${RESET}"
    echo -e "${WHITE}• website-info.sh    : Menampilkan info website${RESET}"
    echo -e "${WHITE}• switch-php.sh      : Mengganti versi PHP${RESET}"
    echo -e "${WHITE}• check-php-versions.sh : Cek status PHP${RESET}"
    echo -e "${WHITE}• backup-to-gdrive.sh : Backup ke Google Drive${RESET}"
    echo
    
    echo -e "${BOLD}🔧 DIRECT USAGE:${RESET}"
    echo -e "${WHITE}Anda juga bisa menjalankan script langsung:${RESET}"
    echo -e "${CYAN}./toolkit.sh --add-website${RESET}"
    echo -e "${CYAN}./toolkit.sh --delete-website${RESET}"
    echo -e "${CYAN}./toolkit.sh --website-info${RESET}"
    echo -e "${CYAN}./toolkit.sh --backup${RESET}"
    echo
    
    echo -e "${BOLD}📁 FILE LOCATIONS:${RESET}"
    echo -e "${WHITE}• Scripts: $SCRIPT_DIR${RESET}"
    echo -e "${WHITE}• Logs: /var/log/toolkit.log${RESET}"
    echo -e "${WHITE}• Apache Config: /etc/apache2/sites-available/${RESET}"
    echo -e "${WHITE}• PHP-FPM Config: /etc/php/*/fpm/pool.d/${RESET}"
    echo
    
    echo -e "${BOLD}🆘 TROUBLESHOOTING:${RESET}"
    echo -e "${WHITE}• Cek log: tail -f /var/log/toolkit.log${RESET}"
    echo -e "${WHITE}• Test Apache: apache2ctl configtest${RESET}"
    echo -e "${WHITE}• Restart services: systemctl restart apache2${RESET}"
    echo -e "${WHITE}• Check permissions: ls -la $SCRIPT_DIR${RESET}"
    echo
}

# Handle command line arguments
handle_arguments() {
    case "$1" in
        --add-website)
            execute_script "$ADD_WEBSITE_SCRIPT" "Add Website" "${@:2}"
            exit 0
            ;;
        --delete-website)
            execute_script "$DELETE_WEBSITE_SCRIPT" "Delete Website" "${@:2}"
            exit 0
            ;;
        --enable-website)
            execute_script "$ENABLE_WEBSITE_SCRIPT" "Enable Website" "${@:2}"
            exit 0
            ;;
        --disable-website)
            execute_script "$DISABLE_WEBSITE_SCRIPT" "Disable Website" "${@:2}"
            exit 0
            ;;
        --website-info)
            execute_script "$WEBSITE_INFO_SCRIPT" "Website Info" "${@:2}"
            exit 0
            ;;
        --switch-php)
            execute_script "$SWITCH_PHP_SCRIPT" "Switch PHP" "${@:2}"
            exit 0
            ;;
        --check-php)
            execute_script "$CHECK_PHP_SCRIPT" "Check PHP" "${@:2}"
            exit 0
            ;;
        --backup)
            execute_script "$BACKUP_SCRIPT" "Backup" "${@:2}"
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            echo -e "${CYAN}Server Management Toolkit v1.0${RESET}"
            exit 0
            ;;
    esac
}

# Wait for user input
wait_for_input() {
    echo
    echo -e "${YELLOW}Tekan Enter untuk melanjutkan...${RESET}"
    read
}

# Main function
main() {
    # Handle command line arguments
    if [ $# -gt 0 ]; then
        handle_arguments "$@"
    fi
    
    # Check root privileges
    check_root
    
    # Create log file
    touch "$LOG_FILE" 2>/dev/null || true
    log_action "Toolkit started"
    
    # Main loop
    while true; do
        show_header
        show_system_status
        show_main_menu
        
        echo -e "${BOLD}Pilih opsi (1-13, h, q): ${RESET}"
        read -p "> " choice
        
        case $choice in
            1)
                execute_script "$ADD_WEBSITE_SCRIPT" "Add Website"
                wait_for_input
                ;;
            2)
                execute_script "$DELETE_WEBSITE_SCRIPT" "Delete Website"
                wait_for_input
                ;;
            3)
                execute_script "$ENABLE_WEBSITE_SCRIPT" "Enable Website"
                wait_for_input
                ;;
            4)
                execute_script "$DISABLE_WEBSITE_SCRIPT" "Disable Website"
                wait_for_input
                ;;
            5)
                execute_script "$WEBSITE_INFO_SCRIPT" "Website Info"
                wait_for_input
                ;;
            6)
                execute_script "$SWITCH_PHP_SCRIPT" "Switch PHP"
                wait_for_input
                ;;
            7)
                execute_script "$CHECK_PHP_SCRIPT" "Check PHP Versions"
                wait_for_input
                ;;
            8)
                execute_script "$BACKUP_SCRIPT" "Backup to Google Drive"
                wait_for_input
                ;;
            9)
                setup_backup
                wait_for_input
                ;;
            10)
                setup_mysql
                wait_for_input
                ;;
            11)
                system_health_check
                wait_for_input
                ;;
            12)
                view_logs
                wait_for_input
                ;;
            13)
                bulk_operations
                wait_for_input
                ;;
            h|H|help)
                show_help
                wait_for_input
                ;;
            q|Q|quit|exit)
                echo -e "${GREEN}👋 Terima kasih telah menggunakan Server Management Toolkit!${RESET}"
                log_action "Toolkit stopped"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Pilihan tidak valid. Silakan coba lagi.${RESET}"
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"
