# Plan: Ansible Role for Deploying Docker Compose Stacks to Portainer

## Overview

Create an Ansible role `portainer-stacks` that deploys Docker Compose stacks from the `apps/` directory to Portainer via its API, with environment variables sourced from Bitwarden Secrets Manager.

## Requirements

1. **Stack Definitions**: Each stack is explicitly defined in Ansible config (not auto-discovered)
2. **Stack Options**: Support overriding stack name per-stack
3. **Environment Variables**: Fetched from Bitwarden Secrets Manager at deploy time (`.env` format)
4. **Idempotent**: Safe to re-run; updates existing stacks, creates new ones
5. **Cleanup**: Removes stacks from Portainer that are no longer in the config

## Current Architecture Context

### Existing Portainer Integration
- `docker-portainer` role at `infra/proxmox/roles/docker-portainer/`
- Already has Portainer API patterns using `uri` module with `X-API-Key` header
- Portainer runs at `https://localhost:9443` on the docker host
- API key stored in vault: `portainer_api_key`

### Docker Compose Files Location
- `apps/*.yaml` - Main stacks (mealie, servarr, home-assistant, etc.). Add these to the initial ansible role config
- `apps/games/*.yaml` - Game server stacks, do not add these to ansible
- `apps/configs/*.yaml` - Config files (not compose stacks), do not add these to ansible

### Compose File Format
Files use environment variable substitution:
```yaml
environment:
  PUID: ${PUID:?err}
  FOLDER_FOR_CONFIGS: ${FOLDER_FOR_CONFIGS:?err}
  SMTP_PASSWORD: ${SMTP_PASSWORD:?err}
```

## Implementation Plan

### 1. Create Role Structure

```
infra/proxmox/roles/portainer-stacks/
├── defaults/main.yml    # Default variables and stack definitions
└── tasks/main.yml       # All tasks in a single file
```

### 2. Role Variables (`defaults/main.yml`)

```yaml
---
# Bitwarden Secrets Manager configuration
bws_access_token: ""  # Set via vault: vault_bws_access_token

# Portainer connection (inherit from docker-portainer role or override)
portainer_url: "https://localhost:{{ portainer_https_port | default(9443) }}"
portainer_api_key: ""  # Set via vault
portainer_endpoint_id: 1  # Default local endpoint

# Stack definitions - list of stacks to deploy
portainer_stacks: []
# Example:
# portainer_stacks:
#   - name: mealie                    # Stack name in Portainer
#     compose_file: mealie.yaml       # Relative to apps/ directory
#     env_secret_id: "uuid-here"      # Bitwarden secret ID containing env vars
#     enabled: true                   # Whether to deploy (default: true)
#   - name: media-stack
#     compose_file: servarr.yaml
#     env_secret_id: "uuid-here"
#     # name defaults to filename without extension if not specified
```

### 3. Tasks (`tasks/main.yml`)

```yaml
---
# --- BWS CLI Installation ---

- name: Check if bws CLI is installed
  command: bws --version
  register: bws_check
  failed_when: false
  changed_when: false

- name: Install bws CLI
  when: bws_check.rc != 0
  block:
    - name: Download bws CLI
      get_url:
        url: "https://github.com/bitwarden/sdk/releases/download/bws-v0.5.0/bws-x86_64-unknown-linux-gnu-0.5.0.zip"
        dest: /tmp/bws.zip
    - name: Unzip bws
      unarchive:
        src: /tmp/bws.zip
        dest: /usr/local/bin/
        remote_src: yes
    - name: Make bws executable
      file:
        path: /usr/local/bin/bws
        mode: '0755'

# --- Portainer API Setup ---

- name: Wait for Portainer API to be ready
  uri:
    url: "{{ portainer_url }}/api/system/status"
    method: GET
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    validate_certs: false
    status_code: 200
  register: portainer_status
  until: portainer_status.status == 200
  retries: 30
  delay: 2

- name: Get list of existing stacks
  uri:
    url: "{{ portainer_url }}/api/stacks"
    method: GET
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    validate_certs: false
  register: existing_stacks

# --- Fetch and Parse BWS Secrets ---

# Filter to only enabled stacks
- name: Build enabled stacks list
  set_fact:
    enabled_stacks: "{{ portainer_stacks | selectattr('enabled', 'undefined') | list + portainer_stacks | selectattr('enabled', 'defined') | selectattr('enabled') | list }}"

# Fetch secrets and parse .env format using Python for robust quote handling
- name: Fetch and parse env vars from Bitwarden
  shell: |
    set -o pipefail
    bws secret get {{ item.env_secret_id }} --output json | python3 -c "
    import sys, json
    data = json.load(sys.stdin)
    content = data.get('value', '')
    result = []
    for line in content.strip().split('\n'):
        line = line.strip()
        if '=' in line and not line.startswith('#'):
            key, val = line.split('=', 1)
            # Strip surrounding quotes (single or double)
            val = val.strip()
            if (val.startswith('\"') and val.endswith('\"')) or (val.startswith(\"'\") and val.endswith(\"'\")):
                val = val[1:-1]
            result.append({'name': key.strip(), 'value': val})
    print(json.dumps(result))
    "
  args:
    executable: /bin/bash
  environment:
    BWS_ACCESS_TOKEN: "{{ bws_access_token }}"
  loop: "{{ enabled_stacks }}"
  loop_control:
    label: "{{ item.name | default(item.compose_file | regex_replace('\\.yaml$', '') | basename) }}"
  when: item.env_secret_id is defined
  register: bws_secrets
  changed_when: false
  no_log: true

# --- Build Stack Data ---

- name: Build stack deployment data
  set_fact:
    stack_data: >-
      {{
        stack_data | default([]) + [{
          'name': item.name | default(item.compose_file | regex_replace('\.yaml$', '') | basename),
          'compose_file': item.compose_file,
          'compose_content': lookup('file', playbook_dir + '/../../../apps/' + item.compose_file),
          'env_list': (bws_secrets.results | selectattr('item.compose_file', 'equalto', item.compose_file) | map(attribute='stdout') | first | default('[]') | from_json)
        }]
      }}
  loop: "{{ enabled_stacks }}"
  loop_control:
    label: "{{ item.name | default(item.compose_file | regex_replace('\\.yaml$', '') | basename) }}"

- name: Get list of managed stack names
  set_fact:
    managed_stack_names: "{{ stack_data | map(attribute='name') | list }}"

# --- Deploy Stacks ---

- name: Create new stacks
  uri:
    url: "{{ portainer_url }}/api/stacks/create/standalone/string?endpointId={{ portainer_endpoint_id }}"
    method: POST
    headers:
      X-API-Key: "{{ portainer_api_key }}"
      Content-Type: application/json
    body_format: json
    body:
      name: "{{ item.name }}"
      stackFileContent: "{{ item.compose_content }}"
      env: "{{ item.env_list }}"
    validate_certs: false
    status_code: [200, 201]
  loop: "{{ stack_data }}"
  loop_control:
    label: "{{ item.name }}"
  when: existing_stacks.json | selectattr('Name', 'equalto', item.name) | list | length == 0

- name: Update existing stacks
  uri:
    url: "{{ portainer_url }}/api/stacks/{{ (existing_stacks.json | selectattr('Name', 'equalto', item.name) | first).Id }}?endpointId={{ portainer_endpoint_id }}"
    method: PUT
    headers:
      X-API-Key: "{{ portainer_api_key }}"
      Content-Type: application/json
    body_format: json
    body:
      stackFileContent: "{{ item.compose_content }}"
      env: "{{ item.env_list }}"
      prune: true
      pullImage: true
    validate_certs: false
    status_code: [200]
  loop: "{{ stack_data }}"
  loop_control:
    label: "{{ item.name }}"
  when: existing_stacks.json | selectattr('Name', 'equalto', item.name) | list | length > 0

# --- Remove Orphaned Stacks ---

- name: Find stacks to remove
  set_fact:
    stacks_to_remove: "{{ existing_stacks.json | rejectattr('Name', 'in', managed_stack_names) | list }}"

- name: Stop orphaned stacks
  uri:
    url: "{{ portainer_url }}/api/stacks/{{ item.Id }}/stop?endpointId={{ item.EndpointId }}"
    method: POST
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    validate_certs: false
    status_code: [200, 204]
  loop: "{{ stacks_to_remove }}"
  loop_control:
    label: "{{ item.Name }}"
  failed_when: false

- name: Remove orphaned stacks
  uri:
    url: "{{ portainer_url }}/api/stacks/{{ item.Id }}?endpointId={{ item.EndpointId }}"
    method: DELETE
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    validate_certs: false
    status_code: [200, 204]
  loop: "{{ stacks_to_remove }}"
  loop_control:
    label: "{{ item.Name }}"
```

### 4. Add to Playbook (`playbook.yaml`)

Add the new role to the Docker play:

```yaml
- name: Configure Docker
  hosts: docker
  gather_facts: false
  roles:
    - { role: docker-portainer, tags: [setup-docker] }
    - { role: portainer-stacks, tags: [setup-docker, deploy-stacks] }
    - { role: docker-cleanup, tags: [setup-docker] }
```

### 6. Configure Stacks (in `group_vars/all/` or role defaults)

Create stack definitions, likely in a new file `group_vars/docker/stacks.yml`:

```yaml
portainer_stacks:
  - name: mealie
    compose_file: mealie.yaml
    env_secret_id: "bws-secret-uuid-for-mealie"

  - name: media
    compose_file: servarr.yaml
    env_secret_id: "bws-secret-uuid-for-servarr"

  - name: home-assistant
    compose_file: home-assistant.yaml
    env_secret_id: "bws-secret-uuid-for-ha"

  - name: scrypted
    compose_file: scrypted.yaml
    env_secret_id: "bws-secret-uuid-for-scrypted"

  - name: syncthing
    compose_file: syncthing.yaml
    env_secret_id: "bws-secret-uuid-for-syncthing"

  - name: ffmpeg
    compose_file: ffmpeg.yaml
    env_secret_id: "bws-secret-uuid-for-ffmpeg"
```

### 7. Vault Updates

Add to `group_vars/all/vault.yml`:

```yaml
vault_bws_access_token: "your-bitwarden-secrets-manager-access-token"
```

### 8. Bitwarden Secrets Manager Setup

In Bitwarden Secrets Manager, create secrets containing environment variables in `.env` format:

```env
# Secret for mealie stack (one secret per stack)
PUID=1000
PGID=1000
TIMEZONE=America/Los_Angeles
FOLDER_FOR_CONFIGS=/mnt/app_config
# Quotes are optional and will be stripped
SMTP_PASSWORD="password with spaces"
ANOTHER_VAR='single quotes work too'
```

Each stack gets its own secret in BWS. The secret's value field contains the full `.env` content. The Python parser handles:
- Unquoted values: `KEY=value`
- Double-quoted values: `KEY="value with spaces"`
- Single-quoted values: `KEY='value'`
- Comments (lines starting with `#` are ignored)

## Files to Create/Modify

| File                                                     | Action | Description                           |
| -------------------------------------------------------- | ------ | ------------------------------------- |
| `infra/proxmox/roles/portainer-stacks/defaults/main.yml` | Create | Role defaults                         |
| `infra/proxmox/roles/portainer-stacks/tasks/main.yml`    | Create | All tasks in single file              |
| `infra/proxmox/playbook.yaml`                            | Modify | Add role to docker play               |
| `infra/proxmox/group_vars/all/vault.yml`                 | Modify | Add BWS token                         |
| `infra/proxmox/group_vars/docker/stacks.yml`             | Create | Stack definitions (optional location) |

## Just Commands

Add to `justfile`:

```just
deploy-stacks:
    just deploy deploy-stacks
```

## Testing

1. Run `just deploy deploy-stacks` to test deployment
2. Verify stacks appear in Portainer UI
3. Verify environment variables are correctly applied
4. Test idempotency by running again
