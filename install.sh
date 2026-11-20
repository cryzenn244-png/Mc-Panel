#!/usr/bin/env bash
set -Eeuo pipefail

# MC Panel bootstrap installer
# Safe defaults: no firewall edits, no existing database deletion, no destructive cleanup.
APP_DIR="${MC_PANEL_DIR:-$HOME/mc-panel}"
APP_PORT="${APP_PORT:-6789}"
BIND_HOST="${APP_HOST:-127.0.0.1}"
NODE_MAJOR="${NODE_MAJOR:-22}"

RED='\033[0;31m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; GREEN='\033[0;32m'; RESET='\033[0m'

banner() {
  clear 2>/dev/null || true
  printf "${RED}╔══════════════════════════════════════════════════════════╗${RESET}\n"
  printf "${RED}║${WHITE}                      MC PANEL                            ${RED}║${RESET}\n"
  printf "${RED}║${DIM}       Premium Hosting Control Platform Bootstrap       ${RED}║${RESET}\n"
  printf "${RED}╚══════════════════════════════════════════════════════════╝${RESET}\n\n"
}
info(){ printf "${CYAN}◆${RESET} %s\n" "$*"; }
ok(){ printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn(){ printf "${RED}!${RESET} %s\n" "$*"; }
die(){ warn "$*"; exit 1; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Required command '$1' is missing."; }

on_error() {
  local code=$?
  printf "\n${RED}Installation stopped (exit %s).${RESET}\n" "$code"
  printf "No existing project data was intentionally deleted.\n"
  exit "$code"
}
trap on_error ERR

banner
printf "${WHITE}This installer prepares the MC Panel project directory and runtime.${RESET}\n"
printf "Target directory: ${CYAN}%s${RESET}\n" "$APP_DIR"
printf "Local URL:        ${CYAN}http://localhost:%s${RESET}\n\n" "$APP_PORT"

if [[ "$EUID" -eq 0 ]]; then
  warn "Running as root. A dedicated non-root account is recommended for app development."
  read -r -p "Continue as root? [y/N] " answer
  [[ "${answer,,}" == "y" ]] || exit 0
fi

if [[ -e "$APP_DIR" ]]; then
  if [[ -d "$APP_DIR" && -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    info "Using existing empty directory."
  else
    warn "Target exists and is not empty: $APP_DIR"
    read -r -p "Use it without overwriting files? [y/N] " answer
    [[ "${answer,,}" == "y" ]] || die "Choose another MC_PANEL_DIR or move the existing directory yourself."
  fi
else
  mkdir -p "$APP_DIR"
fi

mkdir -p "$APP_DIR"/{backend,frontend,agent,deploy,docs,storage,logs}
chmod 750 "$APP_DIR" "$APP_DIR/storage" "$APP_DIR/logs"
cd "$APP_DIR"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  warn "Node.js/npm are missing."
  if command -v apt-get >/dev/null 2>&1; then
    if [[ "$EUID" -ne 0 ]]; then
      warn "Automatic package installation needs root. Install Node.js ${NODE_MAJOR} LTS and npm, then rerun."
      exit 2
    fi
    info "Installing prerequisite tools and Node.js ${NODE_MAJOR} from NodeSource..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" \
      | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
    chmod a+r /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  else
    die "Unsupported package manager. Install Node.js ${NODE_MAJOR} LTS and npm manually."
  fi
fi

need_cmd node
need_cmd npm
node -e 'const v=Number(process.versions.node.split(".")[0]); if(v<20) process.exit(1)' \
  || die "Node.js 20+ required. Install Node.js 22 LTS and rerun."
ok "Node $(node --version) and npm $(npm --version) detected."

# Create safe starter metadata only when absent. Never clobber user files.
if [[ ! -f .env ]]; then
  SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))")"
  cat > .env <<EOF
APP_NAME="MC Panel"
APP_HOST="${BIND_HOST}"
APP_PORT="${APP_PORT}"
APP_URL="http://localhost:${APP_PORT}"
DATABASE_URL="file:./storage/mc-panel.db"
APP_SECRET="${SECRET}"
LOCAL_NODE_ENABLED="true"
LOCAL_NODE_NAME="Local Node"
NODE_ENV="development"
EOF
  chmod 600 .env
  ok "Created .env with a generated secret (mode 600)."
else
  warn ".env already exists; leaving it untouched."
fi

if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<'EOF'
.env
.env.*
!.env.example
node_modules/
dist/
build/
storage/
logs/
*.log
.DS_Store
EOF
fi

if [[ ! -f .env.example ]]; then
  cat > .env.example <<'EOF'
APP_NAME="MC Panel"
APP_HOST="127.0.0.1"
APP_PORT="6789"
APP_URL="http://localhost:6789"
DATABASE_URL="file:./storage/mc-panel.db"
APP_SECRET="replace-with-a-long-random-secret"
LOCAL_NODE_ENABLED="true"
LOCAL_NODE_NAME="Local Node"
NODE_ENV="development"
EOF
fi

cat > INSTALL-STATUS.txt <<EOF
MC Panel bootstrap completed at $(date -Is 2>/dev/null || date)
Project directory: ${APP_DIR}
Node: $(node --version)
npm: $(npm --version)
Configured URL: http://localhost:${APP_PORT}
EOF

printf "\n${GREEN}╭──────────────────────────────────────────────────────────╮${RESET}\n"
printf "${GREEN}│                  BOOTSTRAP COMPLETE                      │${RESET}\n"
printf "${GREEN}╰──────────────────────────────────────────────────────────╯${RESET}\n\n"
ok "Project directory prepared: $APP_DIR"
info "Runtime prerequisites checked."
info "No firewall rules, existing containers, VMs, or system services were changed."
warn "This bootstrap does not magically create the full MC Panel application."
warn "Add the application source/dependency manifests before running the panel."
printf "\nNext steps:\n"
printf "  1. cd '%s'\n" "$APP_DIR"
printf "  2. Review .env and .env.example\n"
printf "  3. Add the MC Panel source code and its package manifests\n"
printf "  4. Run the documented dependency, migration, and start commands for that source\n\n"
