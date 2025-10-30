#!/bin/bash
# install_anti_rusuh_v1.11_autodetect_full.sh
# Auto installer AntiRusuhID untuk Pterodactyl v1.11.x
# WARNING: modifies core files. BACKUP created automatically.

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d%H%M%S)
RAW_BASE="https://raw.githubusercontent.com/samzmarket/anti-rusuh/main"
MW_NAME="AntiRusuhID.php"

# 1) Auto-detect Pterodactyl path (look for artisan)
detect_path() {
  candidates=("/var/www/pterodactyl" "/home/pterodactyl" "/srv/pterodactyl" "/opt/pterodactyl")
  for c in "${candidates[@]}"; do
    if [ -f "$c/artisan" ]; then
      echo "$c"
      return 0
    fi
  done
  # fallback: search from root (may be slow)
  found=$(find / -maxdepth 3 -type f -name artisan 2>/dev/null | head -n1 || true)
  if [ -n "$found" ]; then
    echo "$(dirname "$found")"
    return 0
  fi
  return 1
}

PTERO_PATH=$(detect_path || true)
if [ -z "$PTERO_PATH" ]; then
  echo "ERROR: Tidak dapat menemukan instalasi Pterodactyl (tidak menemukan file artisan)."
  echo "Silakan jalankan script dari direktori yang berisi file artisan atau set var PTERO_PATH secara manual."
  read -p "Masukkan path Pterodactyl (mis. /var/www/pterodactyl), atau kosong untuk batal: " inputp
  if [ -z "$inputp" ]; then
    echo "Abort."
    exit 1
  fi
  PTERO_PATH="$inputp"
fi

echo "Found Pterodactyl at: $PTERO_PATH"

# Paths
MIDDLEWARE_DIR="$PTERO_PATH/app/Http/Middleware"
MIDDLEWARE_PATH="$MIDDLEWARE_DIR/$MW_NAME"
KERNEL_FILE="$PTERO_PATH/app/Http/Kernel.php"
KERNEL_BAK="$KERNEL_FILE.bak.$TIMESTAMP"
ADMIN_CONTROLLERS_DIR="$PTERO_PATH/app/Http/Controllers/Admin"
API_ROUTES="$PTERO_PATH/routes/api.php"
API_BAK="$API_ROUTES.bak.$TIMESTAMP"
ROUTES_WEB="$PTERO_PATH/routes/web.php"
ROUTES_WEB_BAK="$ROUTES_WEB.bak.$TIMESTAMP"

# safety: check artisan exists
if [ ! -f "$PTERO_PATH/artisan" ]; then
  echo "ERROR: artisan tidak ditemukan di $PTERO_PATH. Periksa path."
  exit 1
fi

echo "Backup & prepare..."

# create backups dir
BACKUP_DIR="/root/antirusuh_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# interactive menu
echo "==== AntiRusuhID Auto Installer (v1.11 full) ===="
echo "1) Install AntiRusuhID (recommended)"
echo "2) Uninstall / Restore from backups"
echo "3) Verify current status"
read -p "Pilih opsi [1/2/3]: " CHOICE

# helper functions
backup_file() {
  src="$1"
  if [ -f "$src" ]; then
    cp -a "$src" "$BACKUP_DIR/$(basename "$src").bak.$TIMESTAMP"
    echo "backup: $src -> $BACKUP_DIR/$(basename "$src").bak.$TIMESTAMP"
  fi
}

run_artisan_clear() {
  cd "$PTERO_PATH" || return
  php artisan config:clear || true
  php artisan route:clear || true
  php artisan cache:clear || true
}

install() {
  echo ">> Install: backup core files"
  mkdir -p "$MIDDLEWARE_DIR"
  backup_file "$KERNEL_FILE"
  backup_file "$API_ROUTES"
  backup_file "$ROUTES_WEB"
  if [ -d "$ADMIN_CONTROLLERS_DIR" ]; then
    mkdir -p "$BACKUP_DIR/controllers"
    for f in "$ADMIN_CONTROLLERS_DIR"/*.php; do
      [ -f "$f" ] && cp -a "$f" "$BACKUP_DIR/controllers/$(basename "$f").bak.$TIMESTAMP"
    done
  fi

  echo ">> Download middleware to $MIDDLEWARE_PATH"
  curl -fsSL "$RAW_BASE/$MW_NAME" -o "$MIDDLEWARE_PATH" || { echo "Gagal download middleware"; exit 1; }
  chmod 644 "$MIDDLEWARE_PATH"

  echo ">> Ensure Kernel.php has routeMiddleware entry"
  if ! grep -q "anti.rusuhid" "$KERNEL_FILE"; then
    # insert into $routeMiddleware array
    perl -0777 -pe 's/(protected \$routeMiddleware = \[\s*)/$1\n        '\'''anti.rusuhid'\'' => \\\Pterodactyl\\Http\\Middleware\\AntiRusuhID::class,/' -i "$KERNEL_FILE"
    echo " -> inserted anti.rusuhid into Kernel.php"
  else
    echo " -> Kernel.php sudah berisi anti.rusuhid"
  fi

  echo ">> Try to add anti.rusuhid to api middleware group (if exists)"
  if grep -q "protected \$middlewareGroups" "$KERNEL_FILE"; then
    # add 'anti.rusuhid' to 'api' group if present
    if grep -q "['\"]api['\"]\s*=>\s*\[" "$KERNEL_FILE"; then
      if ! grep -q "anti.rusuhid" "$KERNEL_FILE"; then
        # add into api group near top (non-greedy)
        perl -0777 -pe 's/((\'\''api'\''\s*=>\s*\[)(.*?))/ $1\n        '\''anti.rusuhid'\'',/s' -i "$KERNEL_FILE" 2>/dev/null || true
        # fallback: simpler: insert after "api => ["
        sed -n '1,200p' "$KERNEL_FILE" >/tmp/_ktemp.$$ || true
        # no further action if insertion failed; it's ok
      fi
    fi
  fi

  # Patch controllers: ensure constructor has middleware
  if [ -d "$ADMIN_CONTROLLERS_DIR" ]; then
    echo ">> Patching admin controllers in $ADMIN_CONTROLLERS_DIR"
    for f in "$ADMIN_CONTROLLERS_DIR"/*.php; do
      [ -f "$f" ] || continue
      # if already has middleware line, skip
      if grep -q "\$this->middleware('anti.rusuhid')" "$f"; then
        echo "  - skip $(basename "$f") (already patched)"
        continue
      fi
      # if __construct exists, inject middleware after signature
      if grep -q "function __construct" "$f"; then
        perl -0777 -pe "s/(public function __construct\([^\)]*\)\s*\{)/\$1\n        \\\$this->middleware('anti.rusuhid');/s" -i "$f"
        echo "  - injected into $(basename "$f")"
      else
        # add a constructor with middleware after class opening brace
        perl -0777 -pe "s/(class\s+\w+[^{]*\{)/\$1\n\n    public function __construct() {\n        \$this->middleware('anti.rusuhid');\n    }\n/s" -i "$f"
        echo "  - added __construct in $(basename "$f")"
      fi
    done
  else
    echo ">> Warning: admin controllers dir not found: $ADMIN_CONTROLLERS_DIR"
  fi

  echo ">> Clearing caches..."
  run_artisan_clear

  echo ""
  echo "INSTALL COMPLETE. Backups stored in $BACKUP_DIR"
  echo "Next: edit your /var/www/pterodactyl/.env to set:"
  echo "  ANTI_RUSUH_SUPER_ADMIN_ID=1"
  echo "  ANTI_RUSUH_BOT_API_TOKEN=YourSecretToken"
  echo ""
  echo "Then test with a normal admin account. Check logs: tail -n 200 $PTERO_PATH/storage/logs/laravel-*.log"
}

uninstall() {
  echo ">> UNINSTALL: restoring backups if any..."
  # restore kernel
  if compgen -G "$BACKUP_DIR/Kernel.php.bak.*" > /dev/null; then
    latest=$(ls -1 "$BACKUP_DIR"/Kernel.php.bak.* | sort | tail -n1)
    cp -a "$latest" "$KERNEL_FILE"
    echo "restored Kernel.php from $latest"
  fi
  # restore api routes
  if compgen -G "$BACKUP_DIR/api.php.bak.*" > /dev/null; then
    latest=$(ls -1 "$BACKUP_DIR"/api.php.bak.* | sort | tail -n1)
    cp -a "$latest" "$API_ROUTES"
    echo "restored api.php from $latest"
  fi
  # restore controllers if backups exist
  if [ -d "$BACKUP_DIR/controllers" ]; then
    for b in "$BACKUP_DIR/controllers"/*.bak.*; do
      origname=$(basename "$b" | sed -E 's/\.bak\.[0-9]+$//')
      if [ -f "$ADMIN_CONTROLLERS_DIR/$origname" ]; then
        cp -a "$b" "$ADMIN_CONTROLLERS_DIR/$origname"
        echo "restored $origname"
      fi
    done
  fi
  # remove middleware file
  if [ -f "$MIDDLEWARE_PATH" ]; then
    rm -f "$MIDDLEWARE_PATH"
    echo "removed $MIDDLEWARE_PATH"
  fi
  run_artisan_clear
  echo "UNINSTALL complete. Check $BACKUP_DIR for backups."
}

verify() {
  echo ">> VERIFY: check middleware file & Kernel"
  [ -f "$MIDDLEWARE_PATH" ] && echo "Middleware exists: $MIDDLEWARE_PATH" || echo "MIDDLEWARE MISSING"
  grep -n "anti.rusuhid" "$KERNEL_FILE" || echo "Kernel.php: anti.rusuhid not found"
  echo "Checking controllers for injected middleware..."
  for f in "$ADMIN_CONTROLLERS_DIR"/*.php; do
    [ -f "$f" ] || continue
    if grep -q "\$this->middleware('anti.rusuhid')" "$f"; then
      echo "  - patched: $(basename "$f")"
    else
      echo "  - NOT patched: $(basename "$f")"
    fi
  done
  echo "Route list (application endpoints) (filtered):"
  php "$PTERO_PATH/artisan" route:list --columns=method,uri,name,middleware 2>/dev/null | grep -E "application|admin" || true
}

case "$CHOICE" in
  1) install ;;
  2) uninstall ;;
  3) verify ;;
  *) echo "Invalid choice"; exit 1 ;;
esac
