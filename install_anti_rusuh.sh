#!/bin/bash
# FINAL Auto Installer AntiRusuhID

PTERO_PATH="/var/www/pterodactyl"
MIDDLEWARE_PATH="$PTERO_PATH/app/Http/Middleware/AntiRusuhID.php"
KERNEL_FILE="$PTERO_PATH/app/Http/Kernel.php"
KERNEL_BACKUP="$KERNEL_FILE.bak"
WEB_FILE="$PTERO_PATH/routes/web.php"
WEB_BACKUP="$WEB_FILE.bak"

echo "==== AntiRusuhID Auto Installer ===="
echo "1) Install AntiRusuhID"
echo "2) Hapus AntiRusuhID"
read -p "Pilih opsi [1/2]: " choice

if [ "$choice" == "1" ]; then
    echo ">> Menginstall AntiRusuhID..."

    # 1️⃣ Download middleware
    curl -s https://raw.githubusercontent.com/samzmarket/anti-rusuh/main/AntiRusuhID.php -o "$MIDDLEWARE_PATH"

    # 2️⃣ Backup Kernel.php
    [ ! -f "$KERNEL_BACKUP" ] && cp "$KERNEL_FILE" "$KERNEL_BACKUP"

    # 3️⃣ Tambahkan middleware di Kernel.php jika belum ada
    if ! grep -q "'anti.rusuhid'" "$KERNEL_FILE"; then
        sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'anti.rusuhid' => \\\Pterodactyl\\Http\\Middleware\\AntiRusuhID::class," "$KERNEL_FILE"
    fi

    # 4️⃣ Backup web.php
    [ ! -f "$WEB_BACKUP" ] && cp "$WEB_FILE" "$WEB_BACKUP"

    # 5️⃣ Bungkus semua admin route dengan middleware jika belum ada
    if ! grep -q "anti.rusuhid" "$WEB_FILE"; then
        sed -i "/Route::group(\['middleware' => \['auth'\]\], function () {/a \ \ \ \ Route::group(['middleware'=>['anti.rusuhid']], function() {" "$WEB_FILE"
        sed -i "/Route::group(\['middleware' => \['auth'\]\], function () {/a \ \ \ \ \ \ \ \ # AntiRusuhID block start" "$WEB_FILE"
        sed -i "\$a \ \ \ \ \ \ \ \ # AntiRusuhID block end\n});" "$WEB_FILE"
    fi

    # 6️⃣ Clear cache Laravel
    cd "$PTERO_PATH" || exit
    php artisan config:clear
    php artisan route:clear
    php artisan cache:clear

    echo "✅ AntiRusuhID berhasil diinstall dan aktif!"

elif [ "$choice" == "2" ]; then
    echo ">> Menghapus AntiRusuhID..."

    # Hapus middleware file
    [ -f "$MIDDLEWARE_PATH" ] && rm -f "$MIDDLEWARE_PATH"

    # Restore Kernel.php
    [ -f "$KERNEL_BACKUP" ] && cp "$KERNEL_BACKUP" "$KERNEL_FILE"

    # Restore web.php
    [ -f "$WEB_BACKUP" ] && cp "$WEB_BACKUP" "$WEB_FILE"

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
