# Common ansible command
_ansible := "ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault"

# Sync configuration files to homelab hosts
# Usage: just sync [target]
#   just sync        - sync all (restic + caddy + ssh)
#   just sync caddy  - sync only Caddyfile
#   just sync restic - sync only restic profile
#   just sync ssh    - sync authorized_keys to containers
sync target="":
    {{ _ansible }} --tags {{ if target == "" { "sync" } else { "sync-" + target } }}

# Run full setup including one-time configuration
setup:
    {{ _ansible }}

# Test setup against a different host IP
# Usage: just test <ip> [tags]
#   just test 192.168.0.47         - run full setup against test host
#   just test 192.168.0.47 setup   - run only setup tags
test ip tags="":
    {{ _ansible }} --limit proxmox -e "ansible_host={{ ip }}" {{ if tags != "" { "--tags " + tags } else { "" } }}

# Deploy with a specific tag
# Usage: just deploy [tag]
#   just deploy                  - list available tags
#   just deploy setup-proxmox    - run specific tag
deploy tag="":
    #!/usr/bin/env bash
    if [ -z "{{ tag }}" ]; then
        echo "Available deployment tags:"
        echo ""
        echo "  setup-proxmox       Initial Proxmox setup (repos, ZFS, restic, storage, users, GPU)"
        echo "  setup-caddy         Initial Caddy reverse proxy setup"
        echo "  restore-containers  Restore LXC containers from restic backup"
        echo "  sync                Sync all config files (restic, caddy, ssh)"
        echo "  sync-restic         Sync restic profile only"
        echo "  sync-caddy          Sync Caddyfile only"
        echo "  sync-ssh            Sync SSH authorized_keys to containers"
        echo ""
        echo "Usage: just deploy <tag>"
    else
        {{ _ansible }} --tags "{{ tag }}"
    fi
