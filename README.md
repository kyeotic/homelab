# Homelab

Infrastructure-as-Code for a personal homelab running on Proxmox with LXC containers, Ansible, Docker, and automated backups.

## Architecture

A single Proxmox host manages several LXC containers and services:

| Host                  | IP           | Purpose                                    |
| --------------------- | ------------ | ------------------------------------------ |
| `homelab`             | 192.168.0.10 | Proxmox hypervisor, ZFS storage            |
| `kye-nas`             | 192.168.0.11 | Samba NAS                                  |
| `caddy-container`     | 192.168.0.13 | Caddy reverse proxy with wildcard TLS      |
| `adguard-container`   | 192.168.0.17 | AdGuard Home DNS                           |
| `tailscale-container` | 192.168.0.18 | Tailscale VPN                              |
| `portainer`           | 192.168.0.20 | Docker host running all application stacks |

Caddy handles reverse proxying for all services under `*.local.kye.dev` using DNS-01 challenge with Route53 for wildcard TLS certificates.

## Prerequisites

- [Just](https://github.com/casey/just) task runner
- Ansible with `ansible-vault`
- Vault password stored in `.ansible-vault` (gitignored)
- [vault-sync](https://github.com/kyeotic/vault-sync) for syncing Bitwarden secrets to local `.env` files
- [stack-sync](https://github.com/kyeotic/stack-sync) for deploying Docker stacks to Portainer
- `PORTAINER_API_KEY` environment variable set (create in Portainer under User Settings > Access Tokens)

## Commands

Run all commands from the repository root:

```bash
just setup                          # Full playbook run (all plays)
just deploy                         # List available tags
just deploy <tag>                   # Run a specific tag
just deploy docker-stacks           # Deploy all Portainer stacks
just deploy docker-stacks scrypted  # Deploy a single stack
just deploy docker-stacks --check   # Dry run stack deployment
just test <ip> [tags]               # Run against a different host IP
just ansible-vault-edit             # Edit vault secrets in VS Code
just reset-ssh-hosts                # Clear known_hosts for all inventory IPs
```

### Deployment Tags

| Tag                  | What it does                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| `setup-proxmox`      | Initial Proxmox setup: repos, packages, ZFS pool, restic, LXC users, GPU passthrough, ZED notifications |
| `setup-caddy`        | Create Caddy LXC container and configure reverse proxy                                                  |
| `setup-docker`       | Create Docker LXC, install Portainer, deploy stacks, cleanup timer                                      |
| `setup-samba`        | Create Samba LXC and configure shares                                                                   |
| `setup-adguard`      | Create AdGuard Home LXC                                                                                 |
| `setup-tailscale`    | Create Tailscale LXC                                                                                    |
| `restore-containers` | Restore LXC containers from restic backup                                                               |
| `sync`               | Sync all config files (restic, caddy, ssh)                                                              |
| `sync-restic`        | Sync restic backup profile only                                                                         |
| `sync-caddy`         | Sync Caddyfile only                                                                                     |
| `sync-ssh`           | Sync SSH authorized_keys to containers                                                                  |
| `sync-samba`         | Sync Samba configuration                                                                                |
| `sync-registry`      | Sync Docker registry configuration                                                                      |
| `docker-stacks`      | Deploy/update Docker Compose stacks via Portainer API                                                   |

## Fresh Install

A fresh Proxmox install is configured in stages:

1. Install Proxmox VE on the host and set IP to `192.168.0.10`
2. Place the vault password in `.ansible-vault`
3. Run initial Proxmox setup:
   ```bash
   just deploy setup-proxmox
   ```
   This configures repos, installs packages, creates the ZFS pool (`tank`), sets up restic/resticprofile, configures LXC user mappings, GPU passthrough, and ZED Discord notifications.

4. Set up LXC containers and services:
   ```bash
   just deploy setup-caddy
   just deploy setup-docker
   just deploy setup-samba
   just deploy setup-adguard
   just deploy setup-tailscale
   ```

5. Restore app data from backup (see [Backups](#backups) below), then deploy stacks:
   ```bash
   just deploy docker-stacks
   ```

## Backups

Backups use [restic](https://restic.net/) managed by [resticprofile](https://creativeprojects.github.io/resticprofile/). The configuration lives in `infra/restic/profiles.yaml` and is synced to the Proxmox host at `/root/profiles.yaml`.

### What gets backed up

- `/tank/nas` - NAS file shares
- `/tank/apps` - Application config and data (Docker volumes mount here)
- `/tank/media_root/media/music` - Music library

Large caches (Plex cache/metadata, recyclarr cache) are excluded.

### Backup schedule

| Profile  | Schedule                           | Retention   |
| -------- | ---------------------------------- | ----------- |
| `daily`  | Every day at 04:00 (except Monday) | Keep last 1 |
| `weekly` | Monday at 04:00                    | Keep last 2 |

Backups are sent to a [BorgBase](https://www.borgbase.com/) REST repository.

### Restoring from backup

After a fresh Proxmox install with the ZFS pool recreated:

```bash
# Restic and resticprofile are installed by setup-proxmox
just deploy setup-proxmox

# Restore app data
resticprofile -n daily restore latest --target /
```

### Syncing backup config

After editing `infra/restic/profiles.yaml`:

```bash
just deploy sync-restic
```

This copies the profile to the host and re-registers the systemd schedules.

## Caddy Reverse Proxy

Caddy runs in a container and provides wildcard TLS for `*.local.kye.dev` using Route53 DNS-01 challenge. The Caddyfile at `infra/caddy/Caddyfile` maps subdomains to services on the Docker host.

After editing the Caddyfile:

```bash
just deploy sync-caddy
```

This syncs the file and triggers a live config reload (no container restart needed).

## Application Stacks

Applications run as Docker Compose stacks managed through [Portainer](https://www.portainer.io/). Stack configuration is in `apps/stack-sync.toml` and compose files are in `apps/`.

### How stacks work

Stacks are deployed using [stack-sync](https://github.com/kyeotic/stack-sync), which reads `.stack-sync.toml`:

```toml
host = "https://portainer.local.kye.dev"

[stacks.scrypted]
compose_file = "scrypted.yaml"

[stacks.mealie]
compose_file = "mealie/mealie.yaml"
env_file = "mealie/.env"
```

Stacks that need environment variables have their `.env` files managed by [vault-sync](https://github.com/kyeotic/vault-sync), which syncs secrets from Bitwarden Secrets Manager. The vault-sync config is in `.vault-sync.toml`.

### Adding a new stack

1. Create a compose file in `apps/` (volumes should mount under `/mnt/app_config/<name>`)
2. If the stack needs env vars:
   - Create a secret in Bitwarden Secrets Manager containing the variables in `.env` format
   - Add a vault-sync entry in `.vault-sync.toml` to sync the secret to `apps/<stack>/.env`
   - Create a folder for the stack and place the compose file inside
3. Add the stack to `apps/stack-sync.toml`
4. Sync secrets and deploy:
   ```bash
   vault-sync sync
   just deploy docker-stacks
   ```

## Vault Management

Encrypted secrets are stored in `infra/proxmox/group_vars/all/vault.yml`:

```bash
just ansible-vault-edit              # Edit in VS Code
ansible-vault view infra/proxmox/group_vars/all/vault.yml --vault-password-file .ansible-vault
```
