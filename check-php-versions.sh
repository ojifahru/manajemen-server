#!/bin/bash

# Script untuk mengecek versi PHP yang digunakan oleh setiap website
# Author: Server Management Script
# Version: 2.0
# Description: Menampilkan informasi versi PHP untuk semua website yang dikonfigurasi di Apache

# Fungsi untuk menampilkan bantuan
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help       Tampilkan bantuan ini
    -v, --version    Filter berdasarkan versi PHP tertentu
    -s, --status     Tampilkan status detail website
    -c, --csv        Export ke format CSV
    -j, --json       Export ke format JSON
    --sort           Sort berdasarkan domain/php/status

Examples:
    $0                    # Tampilkan semua website
    $0 -v 8.1            # Tampilkan website dengan PHP 8.1
    $0 -s                # Tampilkan dengan status detail
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

# Fungsi untuk mendapatkan status website
get_website_status() {
    local domain=$1
    local enabled_file="/etc/apache2/sites-enabled/$domain.conf"
    
    if [ -L "$enabled_file" ]; then
        echo "${GREEN}✅ Active${RESET}"
    else
        echo "${RED}❌ Disabled${RESET}"
    fi
}

# Fungsi untuk mendapatkan status PHP-FPM pool
get_pool_status() {
    local username=$1
    local phpver=$2
    local pool_file="/etc/php/$phpver/fpm/pool.d/$username.conf"
    local disabled_pool="/etc/php/$phpver/fpm/pool.d/$username.conf.disabled"
    
    if [ -f "$pool_file" ]; then
        echo "${GREEN}✅ Active${RESET}"
    elif [ -f "$disabled_pool" ]; then
        echo "${YELLOW}⏸️  Disabled${RESET}"
    else
        echo "${RED}❌ Missing${RESET}"
    fi
}

# Fungsi untuk mendapatkan ukuran website
get_website_size() {
    local username=$1
    local user_home="/home/$username"
    
    if [ -d "$user_home" ]; then
        du -sh "$user_home" 2>/dev/null | cut -f1 || echo "N/A"
    else
        echo "N/A"
    fi
}

# Parse arguments
FILTER_VERSION=""
SHOW_STATUS=false
OUTPUT_CSV=false
OUTPUT_JSON=false
SORT_BY="domain"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            FILTER_VERSION="$2"
            shift 2
            ;;
        -s|--status)
            SHOW_STATUS=true
            shift
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
if [ ! -d "$VHOST_DIR" ]; then
    echo "${RED}❌ Error: Direktori Apache sites-available tidak ditemukan: $VHOST_DIR${RESET}"
    exit 1
fi

# Array untuk menyimpan data website
declare -a websites=()

# Kumpulkan data
echo "${CYAN}🔍 Mengumpulkan informasi website...${RESET}"

# Clear array sebelum memulai
websites=()
website_count=0

for file in "$VHOST_DIR"/*.conf; do
    # Skip jika tidak ada file .conf atau file tidak bisa dibaca
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        continue
    fi
    
    domain=$(basename "$file" .conf)
    php_version="No PHP"
    status="Unknown"
    pool_status="N/A"
    size="N/A"
    username=""
    
    # Skip file default Apache atau file kosong
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
    
    # Deteksi versi PHP dengan metode yang lebih robust
    php_version="No PHP"
    username=""
    
    # Method 1: Cari dari SetHandler proxy:unix (modern configuration)
    if grep -q "SetHandler.*proxy:unix.*php.*fpm" "$file"; then
        sock_path=$(grep -oP 'proxy:unix:\K[^|]+' "$file" | head -n1)
        if [[ -n "$sock_path" ]]; then
            php_version=$(echo "$sock_path" | grep -oP 'php\K\d+\.\d+' | head -n1)
            username=$(echo "$sock_path" | grep -oP 'php\d+\.\d+-fpm-\K[^.]+' | head -n1)
        fi
    fi
    
    # Method 2: Fallback ke SetHandler php-fpm (legacy configuration)
    if [[ "$php_version" == "No PHP" ]] && grep -q "SetHandler.*php.*fpm" "$file"; then
        sock_line=$(grep -oP 'php\d+\.\d+-fpm' "$file" | head -n1)
        if [[ -n "$sock_line" ]]; then
            php_version=$(echo "$sock_line" | grep -oP '\d+\.\d+')
            username=$(grep -oP 'php\d+\.\d+-fpm-\K[^.]+' "$file" | head -n1)
        fi
    fi
    
    # Method 3: Cari dari DocumentRoot untuk mendapatkan username
    if [[ -z "$username" ]]; then
        doc_root=$(grep -oP 'DocumentRoot\s+\K[^\s]+' "$file" | head -n1)
        if [[ -n "$doc_root" ]]; then
            username=$(echo "$doc_root" | grep -oP '/home/\K[^/]+' | head -n1)
        fi
    fi
    
    # Fallback username generation dari domain
    if [[ -z "$username" ]]; then
        username=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    
    # Validasi dan normalisasi data
    if [[ -z "$php_version" ]]; then
        php_version="No PHP"
    fi
    
    if [[ -z "$username" ]]; then
        username=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    
    # Filter berdasarkan versi PHP jika diminta
    if [[ -n "$FILTER_VERSION" && "$php_version" != "$FILTER_VERSION" ]]; then
        continue
    fi
    
    # Dapatkan informasi tambahan jika diminta
    if [[ "$SHOW_STATUS" == true ]]; then
        status=$(get_website_status "$domain")
        if [[ "$php_version" != "No PHP" && -n "$username" ]]; then
            pool_status=$(get_pool_status "$username" "$php_version")
            size=$(get_website_size "$username")
        fi
    fi
    
    # Validasi final dan simpan data
    if [[ -n "$domain" && -n "$php_version" ]]; then
        websites+=("$domain|$php_version|$status|$pool_status|$size|$username")
        ((website_count++))
    fi
done

if [[ $website_count -eq 0 ]]; then
    echo "${YELLOW}⚠️ Tidak ada website ditemukan${RESET}"
    if [[ -n "$FILTER_VERSION" ]]; then
        echo "   dengan PHP version $FILTER_VERSION"
    fi
    exit 0
fi

# Fungsi untuk sort data
sort_websites() {
    local sort_field=$1
    
    case $sort_field in
        "domain")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k1,1
            ;;
        "php")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k2,2V
            ;;
        "status")
            printf '%s\n' "${websites[@]}" | sort -t'|' -k3,3
            ;;
        *)
            printf '%s\n' "${websites[@]}"
            ;;
    esac
}

# Export ke CSV
export_csv() {
    local filename="websites_$(date +%Y%m%d_%H%M%S).csv"
    
    if [[ "$SHOW_STATUS" == true ]]; then
        echo "Domain,PHP_Version,Website_Status,Pool_Status,Size,Username" > "$filename"
        while IFS='|' read -r domain php_version status pool_status size username; do
            # Strip ANSI color codes untuk CSV
            status=$(echo "$status" | sed 's/\x1b\[[0-9;]*m//g')
            pool_status=$(echo "$pool_status" | sed 's/\x1b\[[0-9;]*m//g')
            echo "$domain,$php_version,$status,$pool_status,$size,$username" >> "$filename"
        done < <(sort_websites "$SORT_BY")
    else
        echo "Domain,PHP_Version" > "$filename"
        while IFS='|' read -r domain php_version status pool_status size username; do
            echo "$domain,$php_version" >> "$filename"
        done < <(sort_websites "$SORT_BY")
    fi
    
    echo "${GREEN}✅ Data exported ke: $filename${RESET}"
}

# Export ke JSON
export_json() {
    local filename="websites_$(date +%Y%m%d_%H%M%S).json"
    
    echo "{" > "$filename"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$filename"
    echo "  \"total_websites\": $website_count," >> "$filename"
    echo "  \"websites\": [" >> "$filename"
    
    local first=true
    while IFS='|' read -r domain php_version status pool_status size username; do
        # Strip ANSI color codes
        status=$(echo "$status" | sed 's/\x1b\[[0-9;]*m//g')
        pool_status=$(echo "$pool_status" | sed 's/\x1b\[[0-9;]*m//g')
        
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >> "$filename"
        fi
        
        echo -n "    {" >> "$filename"
        echo -n "\"domain\": \"$domain\", " >> "$filename"
        echo -n "\"php_version\": \"$php_version\"" >> "$filename"
        
        if [[ "$SHOW_STATUS" == true ]]; then
            echo -n ", \"website_status\": \"$status\"" >> "$filename"
            echo -n ", \"pool_status\": \"$pool_status\"" >> "$filename"
            echo -n ", \"size\": \"$size\"" >> "$filename"
            echo -n ", \"username\": \"$username\"" >> "$filename"
        fi
        
        echo -n "}" >> "$filename"
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
echo "${BOLD}📊 Website PHP Version Report${RESET}"
echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo "${CYAN}Generated: $(date)${RESET}"
echo "${CYAN}Total websites: $website_count${RESET}"

if [[ -n "$FILTER_VERSION" ]]; then
    echo "${CYAN}Filtered by PHP: $FILTER_VERSION${RESET}"
fi

echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

if [[ "$SHOW_STATUS" == true ]]; then
    printf "${BOLD}%-25s | %-10s | %-12s | %-12s | %-8s${RESET}\n" "Domain" "PHP Ver" "Site Status" "Pool Status" "Size"
    printf "%-25s-+-%-10s-+-%-12s-+-%-12s-+-%-8s\n" "-------------------------" "----------" "------------" "------------" "--------"
    
    while IFS='|' read -r domain php_version status pool_status size username; do
        # Skip entry yang tidak valid
        if [[ -z "$domain" ]]; then
            continue
        fi
        
        # Pastikan php_version tidak kosong
        if [[ -z "$php_version" ]]; then
            php_version="No PHP"
        fi
        
        # Truncate domain jika terlalu panjang
        if [[ ${#domain} -gt 25 ]]; then
            domain="${domain:0:22}..."
        fi
        
        # Color coding untuk PHP version
        if [[ "$php_version" == "No PHP" ]]; then
            php_display="${RED}$php_version${RESET}"
        elif [[ "$php_version" =~ ^[78]\. ]]; then
            php_display="${GREEN}$php_version${RESET}"
        else
            php_display="${YELLOW}$php_version${RESET}"
        fi
        
        printf "%-35s | %-20s | %-22s | %-22s | %-8s\n" "$domain" "$php_display" "$status" "$pool_status" "$size"
    done < <(sort_websites "$SORT_BY")
else
    printf "${BOLD}%-30s | %-15s${RESET}\n" "Domain" "PHP Version"
    printf "%-30s-+-%-15s\n" "------------------------------" "---------------"
    
    while IFS='|' read -r domain php_version status pool_status size username; do
        # Skip entry yang tidak valid
        if [[ -z "$domain" ]]; then
            continue
        fi
        
        # Pastikan php_version tidak kosong
        if [[ -z "$php_version" ]]; then
            php_version="No PHP"
        fi
        
        # Color coding untuk PHP version
        if [[ "$php_version" == "No PHP" ]]; then
            php_display="${RED}⚠️  $php_version${RESET}"
        elif [[ "$php_version" =~ ^[78]\. ]]; then
            php_display="${GREEN}$php_version${RESET}"
        else
            php_display="${YELLOW}❓ $php_version${RESET}"
        fi
        
        printf "%-30s | %-25s\n" "$domain" "$php_display"
    done < <(sort_websites "$SORT_BY")
fi

echo ""
echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

# Tampilkan statistik
echo "${BOLD}📈 PHP Version Statistics:${RESET}"

# Hitung statistik PHP versions
declare -A php_stats
while IFS='|' read -r domain php_version status pool_status size username; do
    # Skip entry yang tidak valid
    if [[ -z "$domain" ]]; then
        continue
    fi
    
    # Sanitize key untuk array
    key="$php_version"
    
    # Pastikan key tidak kosong dan valid
    if [[ -z "$key" ]]; then
        key="No PHP"
    fi
    
    # Hitung statistik
    if [[ -n "${php_stats[$key]:-}" ]]; then
        php_stats[$key]=$((${php_stats[$key]} + 1))
    else
        php_stats[$key]=1
    fi
done < <(printf '%s\n' "${websites[@]}")

# Tampilkan statistik dengan format yang lebih baik
if [[ ${#php_stats[@]} -eq 0 ]]; then
    echo "   ${YELLOW}No statistics available${RESET}"
else
    for version in $(printf '%s\n' "${!php_stats[@]}" | sort -V); do
        count=${php_stats[$version]:-0}
        percentage=$(( count * 100 / website_count ))
        
        if [[ "$version" == "No PHP" ]]; then
            echo "   ${RED}$version${RESET}: $count websites (${percentage}%)"
        else
            echo "   ${GREEN}PHP $version${RESET}: $count websites (${percentage}%)"
        fi
    done
fi

echo "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

if [[ "$SHOW_STATUS" == true ]]; then
    echo ""
    echo "${CYAN}💡 Status Legend:${RESET}"
    echo "   ${GREEN}✅ Active${RESET}: Website dan pool berjalan normal"
    echo "   ${RED}❌ Disabled${RESET}: Website atau pool dinonaktifkan"
    echo "   ${YELLOW}⏸️  Disabled${RESET}: PHP-FPM pool tidak aktif"
    echo "   ${RED}❌ Missing${RESET}: PHP-FPM pool tidak ditemukan"
    echo ""
fi

echo "${CYAN}💡 Usage Tips:${RESET}"
echo "   • Use: $0 -v 8.1 untuk filter PHP 8.1 saja"
echo "   • Use: $0 -s untuk melihat status detail"
echo "   • Use: $0 -c untuk export ke CSV"
echo "   • Use: $0 -j untuk export ke JSON"
echo "   • Use: $0 --sort php untuk sort berdasarkan versi PHP"
