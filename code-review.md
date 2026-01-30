# Ansible Roles Code Review

## Criteria

1. **Clarity** - Task names descriptive, logical ordering, easy to follow
2. **Efficiency** - No redundant steps, proper use of handlers vs tasks
3. **Idempotency** - Safe to re-run without side effects
4. **Convention** - FQCN module names, proper use of `become`, `changed_when`/`failed_when` where needed, variables in defaults
5. **Consistency** - Similar patterns across roles (naming, structure, variable placement)
6. **Correctness** - Potential bugs or logic errors

## Roles

- [x] `pve-post-install`
- [x] `proxmox-packages`
- [x] `zfs-pool`
- [x] `lxc-users`
- [x] `gpu-access`
- [x] `zed-discord`
- [x] `restic`
- [x] `container-ssh`
- [x] `caddy`
- [x] `caddy-lxc`
- [x] `docker-lxc`
- [x] `docker-portainer`
- [x] `docker-cleanup`
- [x] `portainer-stacks`
- [x] `adguard-lxc`
- [x] `samba-lxc`
- [x] `samba-config`
- [x] `tailscale-lxc`

## Future improvements

### Extract shared LXC creation pattern

- [ ] `caddy-lxc`, `docker-lxc`, `samba-lxc`, `adguard-lxc`, `tailscale-lxc` share a nearly identical LXC creation pattern. Consider extracting into a shared role or `include_tasks` with variables.
- The shared pattern covers: list containers, find by hostname, set effective VMID, create container (template download, password check, `pct create`, mount points), clear SSH host key, start container, wait for ready, install SSH sync, wait for SSH, add host key to known_hosts.
- Each role adds service-specific setup after creation (Docker install, AdGuard install, Tailscale install, Samba install, etc.) — this part stays in each role.
- Approach: create a shared `lxc-base` role or a set of `include_tasks` files that accept variables like `lxc_hostname`, `lxc_vmid`, `lxc_ip`, `lxc_mounts`, `lxc_features`, etc. Each `*-lxc` role would call the shared tasks and then run its own service-specific tasks.
- The LXC defaults also share a common structure (`*_lxc_vmid`, `*_lxc_hostname`, `*_lxc_cores`, etc.) — these could be unified into a single variable prefix with the role name as a parameter.

### Other improvements

- [ ] `restic`: No mechanism to upgrade resticprofile once installed. Consider adding a version variable and version check so the install block runs on version mismatch.
- [ ] `restic`: Per-task tags (`setup-proxmox`, `restore-containers`) repeated on every task. Could be cleaner with role-level tags in the playbook, though the `sync` tags on the last task complicate this.
- [ ] `container-ssh`: Large inline shell scripts could be moved to `files/` for maintainability.
- [ ] `zfs-pool`: Dataset configuration block only runs on first pool creation (guarded by `pool_check.rc != 0`). New datasets added to `zfs_datasets` won't be created on re-runs. Consider separating dataset management to run unconditionally when the pool exists.
- [ ] `samba-lxc`/`docker-lxc` defaults share `lxc_template_name: "debian-13-standard_13.1-2_amd64.tar.zst"` — could be a single shared variable in `group_vars`.
