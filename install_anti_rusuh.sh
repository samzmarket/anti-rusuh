#!/bin/bash
# Installer AntiRusuhID Interaktif

PTERO_PATH="/var/www/pterodactyl"
MIDDLEWARE_PATH="$PTERO_PATH/app/Http/Middleware/AntiRusuhID.php"
KERNEL_FILE="$PTERO_PATH/app/Http/Kernel.php"
KERNEL_BACKUP="$KERNEL_FILE.bak"

echo "==== AntiRusuhID Installer ===="
echo "1) Install AntiRusuhID"
echo "2) Hapus AntiRusuhID"
read -p "Pilih opsi [1/2]: " choice

if [ "$choice" == "1" ]; then
    echo ">> Menginstall AntiRusuhID..."
    
    # Download middleware
    curl -s https://raw.githubusercontent.com/samzmarket/anti-rusuh/main/AntiRusuhID.php -o "$MIDDLEWARE_PATH"

    # Backup Kernel.php jika belum ada
    if [ ! -f "$KERNEL_BACKUP" ]; then
        cp "$KERNEL_FILE" "$KERNEL_BACKUP"
    fi

    # Tambahkan middleware jika belum ada
    if ! grep -q "'anti.rusuhid'" "$KERNEL_FILE"; then
        sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'anti.rusuhid' => \\\Pterodactyl\\Http\\Middleware\\AntiRusuhID::class," "$KERNEL_FILE"
    fi

    # Clear cache Laravel
    cd "$PTERO_PATH" || exit
    php artisan config:clear
    php artisan route:clear
    php artisan cache:clear

    echo "✅ AntiRusuhID berhasil diinstall!"

elif [ "$choice" == "2" ]; then
    echo ">> Menghapus AntiRusuhID..."
    
    # Hapus middleware file
    if [ -f "$MIDDLEWARE_PATH" ]; then
        rm -f "$MIDDLEWARE_PATH"
    fi

    # Restore Kernel.php
    if [ -f "$KERNEL_BACKUP" ]; then
        cp "$KERNEL_BACKUP" "$KERNEL_FILE"
    fi

    # Clear cache Laravel
    cd "$PTERO_PATH" || exit
    php artisan config:clear
    php artisan route:clear
    php artisan cache:clear

    echo "✅ AntiRusuhID berhasil dihapus!"
else
    echo "❌ Pilihan tidak valid!"
    exit 1
fi
