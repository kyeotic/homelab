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
- `kye-nas` (192.168.0.11) - Samba LXC (VMID 102)

All SSH connections use `root@<ip>`, e.g. `ssh root@192.168.0.10`.

**Playbook tags:** `setup-proxmox`, `setup-caddy`, `setup-docker`, `setup-samba`, `sync`, `sync-restic`, `sync-caddy`, `sync-ssh`, `sync-samba`, `fix-perms`

### Roles

| Role             | Purpose                                  |
| ---------------- | ---------------------------------------- |
| pve-post-install | Proxmox repo setup, nag removal, updates |
| proxmox-packages | Package installation                     |
| zfs-pool         | ZFS pool and dataset creation            |
| restic           | Backup configuration with resticprofile  |
| lxc-users        | LXC user/group ID mapping                |
| gpu-access       | GPU passthrough udev rules               |
| zed-discord      | ZFS event notifications to Discord       |
| container-ssh    | SSH key distribution                     |
| caddy            | Caddy reverse proxy setup                |
| docker-cleanup   | Docker cleanup systemd timer             |

### Docker Stacks (`apps/`)

Docker Compose stacks are deployed to Portainer via [stack-sync](https://github.com/kyeotic/stack-sync). The config is in `.stack-sync.toml`, which maps each stack name to its compose file (and optional `.env` file) under `apps/`.

To add a new stack:
1. Create a Docker Compose file in `apps/` (single file) or `apps/<name>/` (if it needs an `.env`)
2. Add a `[stacks.<name>]` entry in `.stack-sync.toml` pointing to the compose file (and `env_file` if applicable)
3. Mount persistent data to `/mnt/app_config/<name>/` on the Docker host (e.g., `/mnt/app_config/mealie:/app/data`)
4. If the stack needs a reverse proxy route, add an entry to `infra/caddy/Caddyfile` under the `*.local.kye.dev` block following the existing pattern:
   ```
   @name host name.local.kye.dev
   handle @name {
       reverse_proxy 192.168.0.20:<host-port>
   }
   ```

### Other Directories

- `infra/caddy/` - Caddyfile and Docker Compose for reverse proxy
- `infra/restic/` - Resticprofile backup configuration
- `infra/aws/` - Terraform for Route53 DNS (rarely modified)

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

# Ansible Roles Code Review

## Criteria

1. **Clarity** - Task names descriptive, logical ordering, easy to follow
2. **Efficiency** - No redundant steps, proper use of handlers vs tasks
3. **Idempotency** - Safe to re-run without side effects
4. **Convention** - FQCN module names, proper use of `become`, `changed_when`/`failed_when` where needed, variables in defaults
5. **Consistency** - Similar patterns across roles (naming, structure, variable placement)
6. **Correctness** - Potential bugs or logic errors
