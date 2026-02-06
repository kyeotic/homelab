# Homelab Configuration with Ansible

This directory contains Ansible playbooks to automate configuration of your homelab infrastructure, including the Proxmox host and Caddy reverse proxy container.

## Prerequisites

- Ansible installed on your local machine
- SSH access to your hosts:
  - Proxmox host (configured as `homelab` at `192.168.0.10` in `inventory.yaml`)
  - Caddy container (configured as `caddy-container` at `192.168.0.13` in `inventory.yaml`)
- Root access on both hosts
- The restic password encrypted in `group_vars/proxmox/vault.yml`
- [stack-sync](https://github.com/kyeotic/stack-sync) for deploying Docker stacks to Portainer
- `PORTAINER_API_KEY` environment variable set for stack deployment

## Setup

### 1. Encrypt the Restic Password (First Time Only)

If you haven't already encrypted your vault file:

```bash
cd infra/proxmox

# Edit the vault file and add your restic password
vim group_vars/proxmox/vault.yml

# Encrypt the file
ansible-vault encrypt group_vars/proxmox/vault.yml
```

You'll be prompted to create a vault password. Store this password securely - you'll need it every time you run the playbook.

### 2. Managing the Encrypted Vault

```bash
# View the encrypted file
ansible-vault view group_vars/proxmox/vault.yml

# Edit the encrypted file
ansible-vault edit group_vars/proxmox/vault.yml

# Decrypt the file (not recommended for git-tracked files)
ansible-vault decrypt group_vars/proxmox/vault.yml
```

## Running the Playbook

To run all configuration tasks:

```bash
cd infra/proxmox
ansible-playbook playbook.yaml --ask-vault-pass
```

You'll be prompted for your vault password, then all tasks will run in sequence.

## What Gets Configured

The playbook performs the following tasks:

### 1. Sync Restic Profile
- Copies `../restic/profiles.yaml` to `/root/profiles.yaml` on the Proxmox host
- Configures backup schedules and retention policies

### 2. Create Restic Password File
- Creates `/root/restic-password` with the encrypted password from the vault
- Sets secure permissions (`0600`, owned by root)

### 3. Install Resticprofile
- Downloads the official resticprofile install script
- Installs resticprofile to `/usr/local/bin`
- Only runs if resticprofile isn't already installed

### 4. Create LXC Virtual Users
- Creates the `nas_shares` group with GID `110000` for LXC container mapping
- Creates the `nas` user with UID `101000` in the `nas_shares` group
- Enables proper user/group ID mapping between the host and unprivileged LXC containers
- User is created with a home directory and bash shell

### 5. Configure GPU Access for Unprivileged LXC Containers
- Deploys udev rules to `/etc/udev/rules.d/99-gpu-chmod666.rules`
- Sets permissions on GPU devices (`renderD128`, `kfd`, `card0`) to allow container access
- Automatically reloads udev rules and triggers device updates when changed
- Enables GPU passthrough for unprivileged LXC containers

## Idempotency

All tasks are idempotent, meaning you can safely run the playbook multiple times:
- Files are only updated if content changes
- Binaries are only installed if not present
- Storage is only created if it doesn't exist
- Users and groups are only created if they don't exist
- Udev rules are only reloaded when changed

## Troubleshooting

### Wrong Vault Password
If you enter the wrong vault password, you'll see an error like:
```
ERROR! Decryption failed (no vault secrets were found that could decrypt)
```
Double-check your vault password and try again.

### SSH Connection Issues
If Ansible can't connect to the host:
- Verify the host is accessible: `ping 192.168.0.10`
- Check SSH access: `ssh root@192.168.0.10`
- Ensure the host is defined correctly in `inventory.yaml`

### Task Failures
If a specific task fails, you can:
- Check the error message for details
- SSH into the host to investigate manually
- Re-run the playbook after fixing issues (it will skip successful tasks)
