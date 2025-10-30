#!/bin/bash
# Installer AntiRusuhID Middleware
# Pastikan dijalankan di server Pterodactyl

PTERO_PATH="/var/www/pterodactyl"
SRC_MIDDLEWARE="./AntiRusuhID.php"

# 1️⃣ Buat folder Middleware jika belum ada
mkdir -p "$PTERO_PATH/app/Http/Middleware"

# 2️⃣ Copy file middleware
cp "$SRC_MIDDLEWARE" "$PTERO_PATH/app/Http/Middleware/AntiRusuhID.php"

# 3️⃣ Backup Kernel.php
KERNEL_FILE="$PTERO_PATH/app/Http/Kernel.php"
cp "$KERNEL_FILE" "$KERNEL_FILE.bak"

# 4️⃣ Tambahkan routeMiddleware jika belum ada
if ! grep -q "'anti.rusuhid'" "$KERNEL_FILE"; then
    sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'anti.rusuhid' => \\\Pterodactyl\\Http\\Middleware\\AntiRusuhID::class," "$KERNEL_FILE"
fi

# 5️⃣ Clear cache Laravel
cd "$PTERO_PATH" || exit
php artisan config:clear
php artisan route:clear
php artisan cache:clear

echo "✅ AntiRusuhID berhasil dipasang dan aktif!"
