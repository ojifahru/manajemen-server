#!/bin/bash

# Simple debug script untuk melihat file konfigurasi Apache
VHOST_DIR="/etc/apache2/sites-available"

echo "🔍 Checking Apache configuration files..."
echo "Directory: $VHOST_DIR"
echo ""

if [ ! -d "$VHOST_DIR" ]; then
    echo "❌ Directory not found: $VHOST_DIR"
    exit 1
fi

echo "📁 Files in directory:"
ls -la "$VHOST_DIR"/*.conf 2>/dev/null || echo "No .conf files found"
echo ""

echo "🔍 Analyzing each .conf file:"
for file in "$VHOST_DIR"/*.conf; do
    if [[ ! -f "$file" ]]; then
        continue
    fi
    
    domain=$(basename "$file" .conf)
    echo ""
    echo "=== File: $file ==="
    echo "Domain: $domain"
    echo "File size: $(stat -c%s "$file" 2>/dev/null || echo "unknown") bytes"
    echo "Readable: $([ -r "$file" ] && echo "yes" || echo "no")"
    
    # Check if it's a valid Apache config
    if grep -q "VirtualHost\|ServerName\|DocumentRoot" "$file"; then
        echo "Valid Apache config: yes"
        
        # Check for PHP-FPM configuration
        if grep -q "SetHandler.*php.*fpm" "$file"; then
            echo "Has PHP-FPM: yes"
            
            # Extract PHP version
            sock_line=$(grep -oP 'php\d+\.\d+-fpm' "$file" | head -n1)
            if [[ -n "$sock_line" ]]; then
                php_version=$(echo "$sock_line" | grep -oP '\d+\.\d+')
                echo "PHP Version: $php_version"
            fi
            
            # Extract username
            username=$(grep -oP 'php\d+\.\d+-fpm-\K[^.]+' "$file" | head -n1)
            if [[ -n "$username" ]]; then
                echo "Username: $username"
            fi
        else
            echo "Has PHP-FPM: no"
        fi
        
        # Show DocumentRoot
        doc_root=$(grep -oP 'DocumentRoot\s+\K[^\s]+' "$file" | head -n1)
        if [[ -n "$doc_root" ]]; then
            echo "DocumentRoot: $doc_root"
        fi
        
        # Show ServerName
        server_name=$(grep -oP 'ServerName\s+\K[^\s]+' "$file" | head -n1)
        if [[ -n "$server_name" ]]; then
            echo "ServerName: $server_name"
        fi
        
    else
        echo "Valid Apache config: no"
    fi
    
    echo "--- First 5 lines of file ---"
    head -5 "$file" 2>/dev/null || echo "Cannot read file"
done

echo ""
echo "✅ Debug analysis complete"
