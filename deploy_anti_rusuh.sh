#!/bin/bash
# Deploy Anti Rusuh Middleware Pterodactyl dari GitHub Private Repo
# By Samz Market

set -e

GITHUB_USER="samzmarket"
REPO_NAME="anti-rusuh-pterodactyl"
PROJECT_PATH="/var/www/pterodactyl"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: Environment variable GITHUB_TOKEN tidak ditemukan!"
    echo "Jalankan dulu: export GITHUB_TOKEN='your_personal_access_token'"
    exit 1
fi

TMP_DIR=$(mktemp -d)
git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git "$TMP_DIR"

if [ -f "$TMP_DIR/install_anti_rusuh.sh" ]; then
    chmod +x "$TMP_DIR/install_anti_rusuh.sh"
    bash "$TMP_DIR/install_anti_rusuh.sh"
else
    echo "Installer tidak ditemukan! Abort."
    rm -rf "$TMP_DIR"
    exit 1
fi

rm -rf "$TMP_DIR"
echo "=== Deploy selesai ==="
