#!/usr/bin/env bash
set -Eeuo pipefail

# MC Panel — safe Linux bootstrap installer.
# Installs a small working PHP + Node.js application and a systemd service.
# Does NOT install Docker/libvirt or claim that hosting providers are implemented.

APP_NAME="mc-panel"
APP_DIR="${MC_PANEL_DIR:-/opt/mc-panel}"
APP_USER="${MC_PANEL_USER:-mc-panel}"
APP_GROUP="${MC_PANEL_GROUP:-mc-panel}"
APP_HOST="${APP_HOST:-127.0.0.1}"
APP_PORT="${APP_PORT:-6789}"
NODE_MAJOR="${NODE_MAJOR:-22}"
SERVICE_NAME="mc-panel"
ENV_FILE="/etc/${APP_NAME}/${APP_NAME}.env"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

RED='\033[0;31m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; GREEN='\033[0;32m'; RESET='\033[0m'
info(){ printf "${CYAN}◆${RESET} %s\n" "$*"; }
ok(){ printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn(){ printf "${RED}!${RESET} %s\n" "$*"; }
die(){ warn "$*"; exit 1; }
on_error(){ local code=$?; printf "\n${RED}Installer stopped (exit %s).${RESET}\n" "$code"; exit "$code"; }
trap on_error ERR

clear 2>/dev/null || true
printf "${RED}╔══════════════════════════════════════════════════════════╗${RESET}\n"
printf "${RED}║${WHITE}                      MC PANEL                            ${RED}║${RESET}\n"
printf "${RED}║${DIM}        PHP + Node.js + systemd installation             ${RED}║${RESET}\n"
printf "${RED}╚══════════════════════════════════════════════════════════╝${RESET}\n\n"

[[ "$EUID" -eq 0 ]] || die "Run with sudo: sudo ./install.sh"
[[ -r /etc/os-release ]] || die "Cannot identify Linux distribution."
. /etc/os-release
[[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]] || die "Supported OS: Ubuntu or Debian. Detected: ${PRETTY_NAME:-unknown}"
command -v systemctl >/dev/null 2>&1 || die "systemctl not found. This installer requires a real systemd host, not a container without systemd."

printf "Target: %s\nURL: http://%s:%s\n\n" "$APP_DIR" "$APP_HOST" "$APP_PORT"
warn "This installer changes system packages and installs a systemd unit."
warn "It will not overwrite an existing app directory or existing env file."
read -r -p "Continue? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || exit 0

if [[ -e "$APP_DIR" ]]; then
  [[ -d "$APP_DIR" ]] || die "$APP_DIR exists and is not a directory."
  [[ -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]] || die "$APP_DIR is not empty. Back it up and choose another MC_PANEL_DIR; refusing to overwrite."
else
  mkdir -p "$APP_DIR"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release sudo openssl \
  php-cli php-common php-sqlite3 php-mbstring php-xml php-curl \
  php-zip php-fpm sqlite3

# Install Node.js only if the existing version is absent/too old.
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0])>=20?0:1)'; then
  apt-get install -y ca-certificates curl gnupg
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  chmod a+r /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y nodejs
fi

command -v php >/dev/null || die "PHP CLI install failed."
command -v node >/dev/null || die "Node.js install failed."
command -v npm >/dev/null || die "npm install failed."
command -v systemctl >/dev/null || die "systemctl is required."

if ! getent group "$APP_GROUP" >/dev/null; then groupadd --system "$APP_GROUP"; fi
if ! id "$APP_USER" >/dev/null 2>&1; then
  useradd --system --gid "$APP_GROUP" --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi

# Install source files from this package directory, while protecting existing targets.
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for item in backend frontend agent docs public package.json package-lock.json; do
  if [[ -e "$SOURCE_DIR/$item" ]]; then
    if [[ -e "$APP_DIR/$item" ]]; then
      die "Refusing to overwrite existing $APP_DIR/$item"
    fi
    cp -a "$SOURCE_DIR/$item" "$APP_DIR/"
  fi
done

mkdir -p "$APP_DIR"/{storage,logs,public}
chown -R "$APP_USER:$APP_GROUP" "$APP_DIR"
chmod 750 "$APP_DIR" "$APP_DIR/storage" "$APP_DIR/logs"

install -d -m 0750 -o root -g "$APP_GROUP" "/etc/${APP_NAME}"
if [[ ! -f "$ENV_FILE" ]]; then
  SECRET="$(openssl rand -hex 32)"
  cat > "$ENV_FILE" <<EOF
APP_NAME="MC Panel"
APP_ENV="production"
APP_HOST="${APP_HOST}"
APP_PORT="${APP_PORT}"
APP_URL="http://localhost:${APP_PORT}"
APP_SECRET="${SECRET}"
DATABASE_PATH="${APP_DIR}/storage/mc-panel.sqlite"
EOF
  chown root:"$APP_GROUP" "$ENV_FILE"
  chmod 0640 "$ENV_FILE"
else
  warn "Existing $ENV_FILE retained unchanged."
fi

# Basic app sanity checks before enabling the service.
[[ -f "$APP_DIR/public/index.php" ]] || die "Missing public/index.php in installer package."
[[ -f "$APP_DIR/backend/server.mjs" ]] || die "Missing backend/server.mjs in installer package."
[[ -f "$APP_DIR/package.json" ]] || die "Missing package.json in installer package."

cat > "$UNIT_FILE" <<EOF
[Unit]
Description=MC Panel web application (PHP frontend + Node.js API)
After=network.target
Wants=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
Environment=NODE_ENV=production
Environment=APP_HOST=${APP_HOST}
Environment=APP_PORT=${APP_PORT}
ExecStart=/usr/bin/node ${APP_DIR}/backend/server.mjs
Restart=on-failure
RestartSec=3
TimeoutStopSec=20
KillSignal=SIGTERM
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${APP_DIR}/storage ${APP_DIR}/logs
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
sleep 2
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
  systemctl --no-pager --full status "$SERVICE_NAME" || true
  journalctl -u "$SERVICE_NAME" -n 80 --no-pager || true
  die "MC Panel service did not start. Check journalctl -u ${SERVICE_NAME}."
fi

if command -v curl >/dev/null 2>&1; then
  if curl -fsS "http://${APP_HOST}:${APP_PORT}/api/v1/health" >/dev/null; then
    ok "Health endpoint responded."
  else
    warn "Service is active, but health endpoint did not respond yet. Check logs."
  fi
fi

printf "\n${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}\n"
printf "${GREEN}║               MC PANEL SERVICE INSTALLED                 ║${RESET}\n"
printf "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}\n\n"
printf "Panel:   http://localhost:%s\n" "$APP_PORT"
printf "Service: systemctl status %s\n" "$SERVICE_NAME"
printf "Logs:    journalctl -u %s -f\n" "$SERVICE_NAME"
printf "Config:  %s\n\n" "$ENV_FILE"
warn "PHP CLI/FPM is installed as a compatibility/runtime prerequisite; this starter UI is served by Node and PHP is not yet a Pterodactyl-equivalent backend."
warn "Docker, libvirt/QEMU, Wings-like node agent, customer isolation, and hosting providers are not configured by this installer."
