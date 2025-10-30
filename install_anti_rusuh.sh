#!/bin/bash
# Installer Anti Rusuh Middleware Pterodactyl
# By Samz Market

set -e

PROJECT_PATH="/var/www/pterodactyl"
MIDDLEWARE_PATH="$PROJECT_PATH/app/Http/Middleware"
KERNEL_FILE="$PROJECT_PATH/app/Http/Kernel.php"
ENV_FILE="$PROJECT_PATH/.env"

MIDDLEWARE_FILE="AntiRusuhID.php"

echo "=== Anti Rusuh Installer ==="

# Backup Kernel.php
cp "$KERNEL_FILE" "$KERNEL_FILE.bak_$(date +%Y%m%d%H%M%S)"

# Copy Middleware
mkdir -p "$MIDDLEWARE_PATH"
cp "$MIDDLEWARE_FILE" "$MIDDLEWARE_PATH/$MIDDLEWARE_FILE"

# Tambahkan routeMiddleware di Kernel.php jika belum ada
if ! grep -q "'anti.rusuhid'" "$KERNEL_FILE"; then
    sed -i "/protected \\$routeMiddleware = \\[/a \ \ \ \ 'anti.rusuhid' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\AntiRusuhID::class," "$KERNEL_FILE"
fi

# Tambahkan contoh .env jika belum ada
if ! grep -q "ANTI_RUSUH_SUPER_ADMIN_ID" "$ENV_FILE"; then
    cat <<EOL >> "$ENV_FILE"

# Anti Rusuh Middleware
ANTI_RUSUH_SUPER_ADMIN_ID=1
ANTI_RUSUH_ALLOWED_ADMIN_IDS=45,67
ANTI_RUSUH_BOT_API_TOKEN=tokensecret
EOL
fi

echo "=== Instalasi selesai! ==="
rm -- "$0"
