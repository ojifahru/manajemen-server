#!/bin/bash

# Script untuk mengecek informasi lengkap website di server
# Author: Server Management Script
# Version: 1.0
# Description: Menampilkan informasi user, database, PHP version, dan path untuk setiap website

# Fungsi untuk menampilkan bantuan
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help       Tampilkan bantuan ini
    -u, --user       Filter berdasarkan username tertentu
    -d, --domain     Filter berdasarkan domain tertentu
    -v, --php        Filter berdasarkan versi PHP tertentu
    -c, --csv        Export ke format CSV
    -j, --json       Export ke format JSON
    --sort           Sort berdasarkan user/domain/php/database

Examples:
    $0                    # Tampilkan semua website
    $0 -u johndoe        # Tampilkan website user johndoe
    $0 -d example.com    # Tampilkan website dengan domain example.com
    $0 -v 8.1            # Tampilkan website dengan PHP 8.1
    $0 -c                # Export ke CSV

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

# Fungsi untuk mendapatkan database dari config file
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
    
    # Verifikasi database exists
    local db_exists="No"
    if command -v mysql >/dev/null 2>&1; then
        if mysql -e "USE $db_name" 2>/dev/null; then
            db_exists="Yes"
        fi
    fi
    
    echo "${db_name}|${db_user}|${db_exists}"
}

# Fungsi untuk mendapatkan ukuran direktori
get_directory_size() {
    local path=$1
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "N/A"
    else
        echo "N/A"
    fi
}

# Parse arguments
FILTER_USER=""
FILTER_DOMAIN=""
FILTER_PHP=""
OUTPUT_CSV=false
OUTPUT_JSON=false
SORT_BY="user"

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
        -v|--php)
            FILTER_PHP="$2"
            shift 2
            ;;
        -c|--csv)
            OUTPUT_CSV=true
            shift
            ;;
        -j|--json)
            OUTPUT_JSON=true
            shift
            ;;
        --sort)
            SORT_BY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

VHOST_DIR="/etc/apache2/sites-available"

# Validasi direktori Apache
if [[ ! -d "$VHOST_DIR" ]]; then
    echo "${RED}❌ Error: Direktori Apache sites-available tidak ditemukan: $VHOST_DIR${RESET}"
    exit 1
fi

# Array untuk menyimpan data website
declare -a websites=()

# Kumpulkan data
echo "${CYAN}🔍 Mengumpulkan informasi website...${RESET}"

website_count=0

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
    
    # Inisialisasi variabel
    php_version="No PHP"
    username=""
    doc_root=""
    db_name=""
    db_user=""
    db_exists="No"
    dir_size="N/A"
    
    # Ambil DocumentRoot
    doc_root=$(grep -oP 'DocumentRoot\s+\K[^\s]+' "$file" | head -n1)
    
    # Ambil username dari DocumentRoot
    if [[ -n "$doc_root" ]]; then
        username=$(echo "$doc_root" | grep -oP '/home/\K[^/]+' | head -n1)
        dir_size=$(get_directory_size "$doc_root")
    fi
    
    # Deteksi versi PHP
    if grep -q "SetHandler.*proxy:unix.*php.*fpm" "$file"; then
        sock_path=$(grep -oP 'proxy:unix:\K[^|]+' "$file" | head -n1)
        if [[ -n "$sock_path" ]]; then
            php_version=$(echo "$sock_path" | grep -oP 'php\K\d+\.\d+' | head -n1)
            if [[ -z "$username" ]]; then
                username=$(echo "$sock_path" | grep -oP 'php\d+\.\d+-fpm-\K[^.]+' | head -n1)
            fi
        fi
    fi
    
    # Fallback PHP detection
    if [[ "$php_version" == "No PHP" ]] && grep -q "SetHandler.*php.*fpm" "$file"; then
        sock_line=$(grep -oP 'php\d+\.\d+-fpm' "$file" | head -n1)
        if [[ -n "$sock_line" ]]; then
            php_version=$(echo "$sock_line" | grep -oP '\d+\.\d+')
            if [[ -z "$username" ]]; then
                username=$(grep -oP 'php\d+\.\d+-fpm-\K[^.]+' "$file" | head -n1)
            fi
        fi
    fi
    
    # Fallback username dari domain
    if [[ -z "$username" ]]; then
        username=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    
    # Fallback DocumentRoot
    if [[ -z "$doc_root" ]]; then
        doc_root="/home/$username/public_html"
    fi
    
    # Ambil informasi database
    if [[ -n "$doc_root" && -n "$username" ]]; then
        db_info=$(get_database_info "$domain" "$username" "$doc_root")
        IFS='|' read -r db_name db_user db_exists <<< "$db_info"
    fi
    
    # Aplikasi filter
    if [[ -n "$FILTER_USER" && "$username" != "$FILTER_USER" ]]; then
        continue
    fi
    
    if [[ -n "$FILTER_DOMAIN" && "$domain" != *"$FILTER_DOMAIN"* ]]; then
        continue
    fi
    
    if [[ -n "$FILTER_PHP" && "$php_version" != "$FILTER_PHP" ]]; then
        continue
    fi
    
    # Validasi dan simpan data
    if [[ -n "$domain" && -n "$username" ]]; then
        websites+=("$domain|$username|$php_version|$doc_root|$db_name|$db_user|$db_exists|$dir_size")
        ((website_count++))
    fi
done

if [[ $website_count -eq 0 ]]; then
    echo "${YELLOW}⚠️ Tidak ada website ditemukan${RESET}"
    if [[ -n "$FILTER_USER" ]]; then
        echo "   dengan user: $FILTER_USER"
    fi
    if [[ -n "$FILTER_DOMAIN" ]]; then
        echo "   dengan domain: $FILTER_DOMAIN"
    fi
    if [[ -n "$FILTER_PHP" ]]; then
        echo "   dengan PHP: $FILTER_PHP"
    fi
    exit 0
fi

# Fungsi untuk sort data
sort_websites() {
    local sort_field=$1
    
    case $sort_field in
        "user")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k2,2
            ;;
        "domain")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k1,1
            ;;
        "php")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k3,3V
            ;;
        "database")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k5,5
            ;;
        *)
            printf '%s\n' "${websites[@]}"
            ;;
    esac
}

# Export ke CSV
export_csv() {
    local filename="website_info_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "Domain,Username,PHP_Version,Document_Root,Database_Name,Database_User,Database_Exists,Directory_Size" > "$filename"
    
    while IFS='|' read -r domain username php_version doc_root db_name db_user db_exists dir_size; do
        echo "$domain,$username,$php_version,$doc_root,$db_name,$db_user,$db_exists,$dir_size" >> "$filename"
    done < <(sort_websites "$SORT_BY")
    
    echo "${GREEN}✅ Data exported ke: $filename${RESET}"
}

# Export ke JSON
export_json() {
    local filename="website_info_$(date +%Y%m%d_%H%M%S).json"
    
    echo "{" > "$filename"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$filename"
    echo "  \"total_websites\": $website_count," >> "$filename"
    echo "  \"websites\": [" >> "$filename"
    
    local first=true
    while IFS='|' read -r domain username php_version doc_root db_name db_user db_exists dir_size; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >> "$filename"
        fi
        
        echo "    {" >> "$filename"
        echo "      \"domain\": \"$domain\"," >> "$filename"
        echo "      \"username\": \"$username\"," >> "$filename"
        echo "      \"php_version\": \"$php_version\"," >> "$filename"
        echo "      \"document_root\": \"$doc_root\"," >> "$filename"
        echo "      \"database_name\": \"$db_name\"," >> "$filename"
        echo "      \"database_user\": \"$db_user\"," >> "$filename"
        echo "      \"database_exists\": \"$db_exists\"," >> "$filename"
        echo "      \"directory_size\": \"$dir_size\"" >> "$filename"
        echo -n "    }" >> "$filename"
    done < <(sort_websites "$SORT_BY")
    
    echo "" >> "$filename"
    echo "  ]" >> "$filename"
    echo "}" >> "$filename"
    
    echo "${GREEN}✅ Data exported ke: $filename${RESET}"
}

# Handle export options
if [[ "$OUTPUT_CSV" == true ]]; then
    export_csv
    exit 0
fi

if [[ "$OUTPUT_JSON" == true ]]; then
    export_json
    exit 0
fi

# Tampilkan header report
echo ""
echo "${BOLD}🌐 Website Information Report${RESET}"
echo "${CYAN}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
echo "${CYAN}Generated: $(date)${RESET}"
echo "${CYAN}Total websites: $website_count${RESET}"

if [[ -n "$FILTER_USER" ]]; then
    echo "${CYAN}Filtered by user: $FILTER_USER${RESET}"
fi

if [[ -n "$FILTER_DOMAIN" ]]; then
    echo "${CYAN}Filtered by domain: $FILTER_DOMAIN${RESET}"
fi

if [[ -n "$FILTER_PHP" ]]; then
    echo "${CYAN}Filtered by PHP: $FILTER_PHP${RESET}"
fi

echo "${CYAN}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Tampilkan tabel
printf "${BOLD}%-25s | %-15s | %-8s | %-30s | %-15s | %-10s | %-8s${RESET}\n" "Domain" "Username" "PHP Ver" "Document Root" "Database" "DB User" "Size"
printf "%-25s-+-%-15s-+-%-8s-+-%-30s-+-%-15s-+-%-10s-+-%-8s\n" "-------------------------" "---------------" "--------" "------------------------------" "---------------" "----------" "--------"

while IFS='|' read -r domain username php_version doc_root db_name db_user db_exists dir_size; do
    # Skip entry yang tidak valid
    if [[ -z "$domain" || -z "$username" ]]; then
        continue
    fi
    
    # Truncate jika terlalu panjang
    if [[ ${#domain} -gt 25 ]]; then
        domain_display="${domain:0:22}..."
    else
        domain_display="$domain"
    fi
    
    if [[ ${#username} -gt 15 ]]; then
        username_display="${username:0:12}..."
    else
        username_display="$username"
    fi
    
    if [[ ${#doc_root} -gt 30 ]]; then
        doc_root_display="...${doc_root: -27}"
    else
        doc_root_display="$doc_root"
    fi
    
    if [[ ${#db_name} -gt 15 ]]; then
        db_name_display="${db_name:0:12}..."
    else
        db_name_display="$db_name"
    fi
    
    if [[ ${#db_user} -gt 10 ]]; then
        db_user_display="${db_user:0:7}..."
    else
        db_user_display="$db_user"
    fi
    
    # Color coding untuk PHP version
    if [[ "$php_version" == "No PHP" ]]; then
        php_display="${RED}$php_version${RESET}"
    elif [[ "$php_version" =~ ^[78]\. ]]; then
        php_display="${GREEN}$php_version${RESET}"
    else
        php_display="${YELLOW}$php_version${RESET}"
    fi
    
    # Color coding untuk database
    if [[ "$db_exists" == "Yes" ]]; then
        db_display="${GREEN}$db_name_display${RESET}"
    else
        db_display="${RED}$db_name_display${RESET}"
    fi
    
    printf "%-35s | %-25s | %-18s | %-30s | %-25s | %-20s | %-8s\n" \
        "$domain_display" \
        "$username_display" \
        "$php_display" \
        "$doc_root_display" \
        "$db_display" \
        "$db_user_display" \
        "$dir_size"
done < <(sort_websites "$SORT_BY")

echo ""
echo "${CYAN}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"

# Tampilkan statistik
echo "${BOLD}📊 Statistics:${RESET}"

# Statistik PHP
declare -A php_stats
declare -A user_stats
declare -A db_stats

while IFS='|' read -r domain username php_version doc_root db_name db_user db_exists dir_size; do
    if [[ -z "$domain" ]]; then
        continue
    fi
    
    # PHP stats
    if [[ -n "${php_stats[$php_version]:-}" ]]; then
        php_stats[$php_version]=$((${php_stats[$php_version]} + 1))
    else
        php_stats[$php_version]=1
    fi
    
    # User stats
    if [[ -n "${user_stats[$username]:-}" ]]; then
        user_stats[$username]=$((${user_stats[$username]} + 1))
    else
        user_stats[$username]=1
    fi
    
    # Database stats
    if [[ -n "${db_stats[$db_exists]:-}" ]]; then
        db_stats[$db_exists]=$((${db_stats[$db_exists]} + 1))
    else
        db_stats[$db_exists]=1
    fi
done < <(printf '%s\n' "${websites[@]}")

echo ""
echo "${BOLD}🐘 PHP Versions:${RESET}"
for version in $(printf '%s\n' "${!php_stats[@]}" | sort -V); do
    count=${php_stats[$version]:-0}
    if [[ "$version" == "No PHP" ]]; then
        echo "   ${RED}$version${RESET}: $count websites"
    else
        echo "   ${GREEN}PHP $version${RESET}: $count websites"
    fi
done

echo ""
echo "${BOLD}🗄️ Database Status:${RESET}"
for status in $(printf '%s\n' "${!db_stats[@]}" | sort); do
    count=${db_stats[$status]:-0}
    if [[ "$status" == "Yes" ]]; then
        echo "   ${GREEN}Database Found${RESET}: $count websites"
    else
        echo "   ${RED}Database Not Found${RESET}: $count websites"
    fi
done

echo ""
echo "${BOLD}👤 Top Users:${RESET}"
printf '%s\n' "${!user_stats[@]}" | while read -r user; do
    count=${user_stats[$user]:-0}
    echo "$count $user"
done | sort -rn | head -5 | while read -r count user; do
    echo "   ${CYAN}$user${RESET}: $count websites"
done

echo ""
echo "${CYAN}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"

echo "${CYAN}💡 Usage Tips:${RESET}"
echo "   • Use: $0 -u username untuk filter user tertentu"
echo "   • Use: $0 -d domain.com untuk filter domain tertentu"
echo "   • Use: $0 -v 8.1 untuk filter PHP 8.1 saja"
echo "   • Use: $0 -c untuk export ke CSV"
echo "   • Use: $0 -j untuk export ke JSON"
echo "   • Use: $0 --sort database untuk sort berdasarkan database"
