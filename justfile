# Sync configuration files to homelab hosts
sync:
    ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault --tags sync

# Run full setup including one-time configuration
setup:
    ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault
