#!/bin/bash
# Installer FINAL AntiRusuhID Pterodactyl v1.11
PTERO_PATH="/var/www/pterodactyl"
MIDDLEWARE_PATH="$PTERO_PATH/app/Http/Middleware/AntiRusuhID.php"
KERNEL_FILE="$PTERO_PATH/app/Http/Kernel.php"
KERNEL_BACKUP="$KERNEL_FILE.bak"
ADMIN_CONTROLLERS="$PTERO_PATH/app/Http/Controllers/Admin"

echo "==== AntiRusuhID Installer v1.11 ===="
echo "1) Install AntiRusuhID"
echo "2) Hapus AntiRusuhID"
read -p "Pilih opsi [1/2]: " choice

install_middleware() {
    # Copy middleware
    curl -s https://raw.githubusercontent.com/samzmarket/anti-rusuh/main/AntiRusuhID.php -o "$MIDDLEWARE_PATH"
    
    # Backup Kernel.php
    [ ! -f "$KERNEL_BACKUP" ] && cp "$KERNEL_FILE" "$KERNEL_BACKUP"
    
    # Tambahkan middleware di Kernel.php jika belum ada
    if ! grep -q "'anti.rusuhid'" "$KERNEL_FILE"; then
        sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'anti.rusuhid' => \\\Pterodactyl\\Http\\Middleware\\AntiRusuhID::class," "$KERNEL_FILE"
    fi
    
    # Tambahkan middleware ke semua controller admin
    for file in "$ADMIN_CONTROLLERS"/*.php; do
        if ! grep -q "\$this->middleware('anti.rusuhid')" "$file"; then
            sed -i "/public function __construct()/a \ \ \ \ \$this->middleware('anti.rusuhid');" "$file"
        fi
    done

    # Clear cache Laravel
    cd "$PTERO_PATH" || exit
    php artisan config:clear
    php artisan route:clear
    php artisan cache:clear

    echo "✅ AntiRusuhID berhasil diinstall dan aktif!"
}

remove_middleware() {
    # Hapus middleware
    [ -f "$MIDDLEWARE_PATH" ] && rm -f "$MIDDLEWARE_PATH"

    # Restore Kernel.php
    [ -f "$KERNEL_BACKUP" ] && cp "$KERNEL_BACKUP" "$KERNEL_FILE"

    # Hapus middleware dari controller
    for file in "$ADMIN_CONTROLLERS"/*.php; do
        sed -i "/\\\$this->middleware('anti.rusuhid');/d" "$file"
    done

    # Clear cache Laravel
    cd "$PTERO_PATH" || exit
    php artisan config:clear
    php artisan route:clear
    php artisan cache:clear

    echo "✅ AntiRusuhID berhasil dihapus!"
}

if [ "$choice" == "1" ]; then
    echo ">> Menginstall AntiRusuhID..."
    install_middleware
elif [ "$choice" == "2" ]; then
    echo ">> Menghapus AntiRusuhID..."
    remove_middleware
else
    echo "❌ Pilihan tidak valid!"
    exit 1
fi
