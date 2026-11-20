# Feature status

## Implemented in this starter

- Dark responsive dashboard.
- Node.js HTTP service on port 6789.
- Health endpoint at `/api/v1/health`.
- Real host telemetry endpoint at `/api/v1/system`.
- Optional token-protected starter admin endpoints.
- PHP CLI/FPM packages requested by installer and a PHP runtime-check page.
- systemd service template, non-root service account, restricted filesystem write paths.
- Safe bootstrap behavior that refuses to overwrite a non-empty app directory.

## Not implemented

- Laravel or Pterodactyl-compatible panel backend.
- Persistent user database, sessions, password reset, roles and full RBAC.
- Docker workload creation/management.
- PM2 customer workload isolation.
- QEMU/KVM/libvirt VM provisioning.
- Node agent and remote-node authentication.
- Eggs/Nests deployment engine.
- Minecraft server and Discord bot lifecycle management.
- Workload-scoped file manager, backups, quotas, resource reservations and WebSockets.
- Production reverse proxy, TLS, queue workers, migrations and end-to-end tests.

The starter must not be marketed as production-ready hosting software until these features are implemented and tested.
