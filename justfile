# Common ansible command
_ansible := "ansible-playbook -i infra/proxmox/inventory.yaml infra/proxmox/playbook.yaml --vault-password-file .ansible-vault"

# Run full setup including one-time configuration
setup:
    {{ _ansible }}

ansible-vault-edit:
    EDITOR='code --wait'  ansible-vault edit infra/proxmox/group_vars/all/vault.yml --vault-password-file .ansible-vault

# Pulls need no login. The password comes from the vault and is never printed.
# Log this machine's docker in to docker.local.kye.dev so it can push images (once per machine)
registry-login:
    #!/usr/bin/env bash
    set -euo pipefail
    password="$(ansible-vault view infra/proxmox/group_vars/all/vault.yml --vault-password-file .ansible-vault \
      | sed -n 's/^registry_push_password: "\(.*\)"$/\1/p')"
    [[ -n "$password" ]] || { echo "registry_push_password isn't in the vault (git pull?)" >&2; exit 1; }
    printf '%s' "$password" | docker login -u push --password-stdin docker.local.kye.dev

# For a leaked password: a new one in the vault, Caddy reloaded, this machine logged in again.
# Every other machine that pushes then needs `just registry-login`. Commit and push the vault.
# Replace the registry push password (old one stops working at once)
registry-rotate:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    vault=infra/proxmox/group_vars/all/vault.yml
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    password="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(32))')"
    hash="$(docker run --rm -e P="$password" ghcr.io/caddybuilds/caddy-cloudflare:latest sh -c 'caddy hash-password --plaintext "$P"')"
    ansible-vault view "$vault" --vault-password-file .ansible-vault > "$tmp/v.yml"
    P="$password" H="$hash" python3 -I -c 'import os, re, sys; p = sys.argv[1]; s = open(p).read(); s = re.sub(r"(?m)^registry_push_password: .*$", "registry_push_password: \"%s\"" % os.environ["P"], s); s = re.sub(r"(?m)^registry_push_hash: .*$", "registry_push_hash: \"%s\"" % os.environ["H"], s); open(p, "w").write(s)' "$tmp/v.yml"
    ansible-vault encrypt "$tmp/v.yml" --vault-password-file .ansible-vault --output "$vault" >/dev/null
    just deploy sync-caddy
    just registry-login
    echo "Rotated. Commit and push $vault, then run just registry-login on every other machine that pushes."

# Clear SSH known_hosts entries for all inventory hosts (use before reinstalling systems)
reset-ssh-hosts:
    ssh-keygen -f ~/.ssh/known_hosts -R 192.168.0.10
    ssh-keygen -f ~/.ssh/known_hosts -R 192.168.0.13
    ssh-keygen -f ~/.ssh/known_hosts -R 192.168.0.20

# Test setup against a different host IP
# Usage: just test <ip> [tags]
#   just test 192.168.0.47         - run full setup against test host
#   just test 192.168.0.47 setup   - run only setup tags
test ip tags="":
    {{ _ansible }} --limit proxmox -e "ansible_host={{ ip }}" {{ if tags != "" { "--tags " + tags } else { "" } }}

# Deploy DNS/Cloudflare terraform (infra/dns)
deploy-tf:
    infra/dns/deploy

# Deploy with a specific tag
# Usage: just deploy [tag] [args]
#   just deploy                            - list available tags
#   just deploy setup-proxmox              - run specific tag
#   just deploy docker-stacks              - deploy all stacks
#   just deploy docker-stacks scrypted     - deploy one or more named stacks
#   just deploy docker-stacks --check      - dry run (stack-sync --dry-run)
deploy tag="" *args="":
    #!/usr/bin/env bash
    if [ -z "{{ tag }}" ]; then
        echo "Available deployment tags:"
        echo ""
        echo "  setup-proxmox       Initial Proxmox setup (repos, ZFS, restic, storage, users, GPU)"
        echo "  setup-caddy         Initial Caddy reverse proxy setup"
        echo "  setup-docker        Docker host setup (Docker, port-gate firewall, Arcane dirs, stacks, cleanup timer)"
        echo "  restore-containers  Restore LXC containers from restic backup"
        echo "  sync                Sync all config files (restic, caddy, ssh, sshd)"
        echo "  sync-restic         Sync restic profile only"
        echo "  sync-caddy          Sync Caddyfile only"
        echo "  sync-ssh            Sync SSH authorized_keys to containers"
        echo "  sync-sshd           Sync sshd hardening (key-only login) to Proxmox and all LXCs"
        echo "  sync-firewall       Sync docker host port-gate rules (TinyAuth-gated app ports)"
        echo "  docker-stacks       Deploy Docker Compose stacks (including Arcane) with stack-sync"
        echo ""
        echo "Usage: just deploy <tag>"
        echo "       just deploy docker-stacks [stack...] [--check]"
    elif [ "{{ tag }}" = "docker-stacks" ]; then
        # Special handling for docker-stacks: parse stack names and --check
        check_flag=""
        stacks=()
        for arg in {{ args }}; do
            if [ "$arg" = "--check" ]; then
                check_flag="--check"
            else
                stacks+=("$arg")
            fi
        done
        filter_arg=()
        if [ ${#stacks[@]} -gt 0 ]; then
            filter_arg=(-e "docker_stacks_filter='${stacks[*]}'")
        fi
        {{ _ansible }} --tags docker-stacks "${filter_arg[@]}" $check_flag
    else
        {{ _ansible }} --tags "{{ tag }}" {{ args }}
    fi
