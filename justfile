# Common ansible command
_ansible := "ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault"

# Sync configuration files to homelab hosts
# Usage: just sync [target]
#   just sync        - sync all (restic + caddy)
#   just sync caddy  - sync only Caddyfile
#   just sync restic - sync only restic profile
sync target="":
    {{ _ansible }} --tags {{ if target == "" { "sync" } else { "sync-" + target } }}

# Run full setup including one-time configuration
setup:
    {{ _ansible }}
