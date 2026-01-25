# Common ansible command
_ansible := "ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault"

# Run full setup including one-time configuration
setup:
    {{ _ansible }}

ansible-vault-edit:
    EDITOR='code --wait'  ansible-vault edit infra/proxmox/group_vars/all/vault.yml --vault-password-file .ansible-vault

# Test setup against a different host IP
# Usage: just test <ip> [tags]
#   just test 192.168.0.47         - run full setup against test host
#   just test 192.168.0.47 setup   - run only setup tags
test ip tags="":
    {{ _ansible }} --limit proxmox -e "ansible_host={{ ip }}" {{ if tags != "" { "--tags " + tags } else { "" } }}

# Deploy with a specific tag
# Usage: just deploy [tag] [args]
#   just deploy                            - list available tags
#   just deploy setup-proxmox              - run specific tag
#   just deploy docker-stacks              - deploy all stacks
#   just deploy docker-stacks scrypted     - deploy single stack
#   just deploy docker-stacks --check      - dry run
deploy tag="" *args="":
    #!/usr/bin/env bash
    if [ -z "{{ tag }}" ]; then
        echo "Available deployment tags:"
        echo ""
        echo "  setup-proxmox       Initial Proxmox setup (repos, ZFS, restic, storage, users, GPU)"
        echo "  setup-caddy         Initial Caddy reverse proxy setup"
        echo "  setup-docker        Docker host setup (cleanup timer)"
        echo "  restore-containers  Restore LXC containers from restic backup"
        echo "  sync                Sync all config files (restic, caddy, ssh)"
        echo "  sync-restic         Sync restic profile only"
        echo "  sync-caddy          Sync Caddyfile only"
        echo "  sync-ssh            Sync SSH authorized_keys to containers"
        echo "  docker-stacks       Deploy Docker Compose stacks to Portainer"
        echo ""
        echo "Usage: just deploy <tag>"
        echo "       just deploy docker-stacks [stack] [--check]"
    elif [ "{{ tag }}" = "docker-stacks" ]; then
        # Special handling for docker-stacks: parse stack filter and --check
        check_flag=""
        stack_filter=""
        for arg in {{ args }}; do
            if [ "$arg" = "--check" ]; then
                check_flag="--check"
            else
                stack_filter="$arg"
            fi
        done
        filter_arg=""
        if [ -n "$stack_filter" ]; then
            filter_arg="-e portainer_stack_filter=$stack_filter"
        fi
        {{ _ansible }} --tags docker-stacks $filter_arg $check_flag
    else
        {{ _ansible }} --tags "{{ tag }}" {{ args }}
    fi
