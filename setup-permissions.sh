#!/bin/bash

# Script untuk setup permissions setelah git clone
# Jalankan script ini setelah clone repository

echo "Setting up file permissions..."

# Berikan permission executable untuk semua script .sh
chmod +x *.sh

echo "Permissions set successfully!"
echo "All .sh files now have executable permission"

# Tampilkan status permission
echo ""
echo "Current permissions:"
ls -la *.sh
