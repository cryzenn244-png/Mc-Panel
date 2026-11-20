# MC Panel — project bootstrap

MC Panel is intended to become a unified Minecraft, Discord bot, container, node, and QEMU/KVM VPS management platform, available at `http://localhost:6789`.

## Directory layout

```text
mc-panel/
├── backend/       # API, auth, database and background jobs
├── frontend/      # web UI
├── agent/         # isolated node agent
├── deploy/        # service and reverse-proxy examples
├── docs/          # architecture, setup and security documentation
├── storage/       # local development data (ignored by Git)
├── logs/          # local logs (ignored by Git)
├── .env           # generated local settings; do not commit
├── .env.example
├── .gitignore
└── install.sh
```

## Install the bootstrap

On Ubuntu/Debian, from the directory containing `install.sh`:

```bash
chmod +x install.sh
./install.sh
```

The installer targets `$HOME/mc-panel` by default. To choose another path:

```bash
MC_PANEL_DIR="$HOME/projects/mc-panel" ./install.sh
```

The script checks for Node.js 20+ and npm. If they are missing on Ubuntu/Debian and the script is run as root, it offers an automated Node.js 22 LTS installation. It creates the project folders and starter environment files without overwriting existing files. It does not modify firewall rules, delete data, remove containers, or delete virtual machines.

## Important status

This bootstrap creates the directory and local configuration only. It is **not** a complete hosting panel and does not yet provide functional authentication, Docker/PM2 management, QEMU/KVM provisioning, Eggs/Nests, backups, or a web server. Those require application source code, dependency manifests, migrations, providers, and tests. Do not treat the generated directory as production-ready.

## Infrastructure safety

- Do not expose the Docker socket or libvirt management socket to browser clients.
- Run customer workloads with isolation and per-workload resource limits.
- Use a dedicated node agent for privileged operations.
- Use a supported service manager for production and configure HTTPS behind a reverse proxy.
- Test VM provisioning and backups on a disposable test host before using customer data.
