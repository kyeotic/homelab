# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure-as-Code for a personal homelab using Ansible, Proxmox, and Docker. The primary work is managing Ansible configuration in `infra/`.

## Common Commands

All commands run from the repository root using Just (task runner):

```bash
just setup                    # Full Ansible playbook run
just deploy <tag>             # Run specific tag (run without args to list tags)
just deploy setup-proxmox     # Initial Proxmox setup
just deploy sync              # Sync all config files (restic, caddy, ssh)
just deploy sync-caddy        # Sync only Caddyfile
just test <ip> [tags]         # Test against a different host IP
```

The vault password file is `.ansible-vault` (gitignored). All ansible-playbook commands use `--vault-password-file .ansible-vault`.

## Architecture

### Ansible Structure (`infra/proxmox/`)

```
infra/proxmox/
├── playbook.yaml          # Main playbook with 3 plays: proxmox, caddy, docker
├── inventory.yaml         # Host definitions (proxmox, caddy, docker groups)
├── group_vars/all/vault.yml  # Encrypted secrets (ansible-vault)
└── roles/                 # Ansible roles
```

**Key hosts:**
- `homelab` (192.168.0.10) - Proxmox host
- `caddy-container` (192.168.0.13) - Caddy reverse proxy
- `docker` (192.168.0.20) - Docker/Portainer host

**Playbook tags:** `setup-proxmox`, `setup-caddy`, `setup-docker`, `sync`, `sync-restic`, `sync-caddy`, `sync-ssh`

### Roles

| Role | Purpose |
|------|---------|
| pve-post-install | Proxmox repo setup, nag removal, updates |
| proxmox-packages | Package installation |
| zfs-pool | ZFS pool and dataset creation |
| restic | Backup configuration with resticprofile |
| lxc-users | LXC user/group ID mapping |
| gpu-access | GPU passthrough udev rules |
| zed-discord | ZFS event notifications to Discord |
| container-ssh | SSH key distribution |
| caddy | Caddy reverse proxy setup |
| docker-cleanup | Docker cleanup systemd timer |

### Other Directories

- `infra/caddy/` - Caddyfile and Docker Compose for reverse proxy
- `infra/restic/` - Resticprofile backup configuration
- `infra/aws/` - Terraform for Route53 DNS (rarely modified)
- `apps/` - Docker Compose files for services (rarely modified)

## Vault Management

```bash
ansible-vault view infra/proxmox/group_vars/all/vault.yml
ansible-vault edit infra/proxmox/group_vars/all/vault.yml
```

## Conventions

- All Ansible tasks must be idempotent (safe to re-run)
- Role variables go in `roles/<role>/defaults/main.yml`
- Encrypted secrets use Ansible Vault in `group_vars/all/vault.yml`
- Tags control which parts of the playbook run
