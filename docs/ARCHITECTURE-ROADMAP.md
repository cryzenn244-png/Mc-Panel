# Architecture roadmap

This document records the intended implementation boundary; it does not claim the features are already implemented.

## Proposed stack

- TypeScript/Node.js API and frontend tooling.
- PostgreSQL for production persistence; SQLite may be used only for a deliberately supported local-development mode.
- A durable job queue for provisioning and backups.
- Docker API access through a privileged, narrow node agent.
- PM2 only for trusted Node.js applications; isolate customer code.
- QEMU/KVM through libvirt on supported Linux hosts.
- Authenticated WebSockets for logs and job progress.

Before implementation, choose exact framework versions, commit lockfiles, add migrations and provider tests, and document the supported OS.

## Release gates

1. Authentication, authorization, sessions, audit logs and secret redaction.
2. Database migrations and transactional capacity reservations.
3. Node heartbeat and measured CPU/RAM/disk telemetry.
4. Docker workload lifecycle with strict mount/image/port validation.
5. Isolated PM2 support, or container-only execution for untrusted code.
6. Libvirt provider with real integration tests on a KVM-capable host.
7. Egg/Nest validation and a controlled, non-root install environment.
8. Minecraft and bot templates tested against actual runtime versions.
9. Workload-scoped file manager, quotas and tested restore procedures.
10. Automated unit, integration and end-to-end tests.

## Non-goals for bootstrap

The installer does not install or configure Docker, libvirt, firewall rules, SSH, or production services. It does not provision VMs or launch customer code.
