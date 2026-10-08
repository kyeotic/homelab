# Arcane migration handoff

Written 2026-10-06. Goal: replace Dockru (our Rust fork of Dockge, `apps/dockru.yaml`) with
[Arcane](https://github.com/getarcaneapp/arcane) as the Docker compose stack manager on the
docker host (192.168.0.20). Like the earlier Dockge migration (`dockge.md`), do this in phases
with manual verification between them.

## Arcane facts the next session needs

- Repo: https://github.com/getarcaneapp/arcane (old `ofkm/arcane` redirects).
  Docs: https://getarcane.app/docs. Image: `ghcr.io/getarcaneapp/manager`. Latest seen: v2.15.0.
- Go backend, SvelteKit UI, SQLite by default, BSD-3 license. Single container.
- Projects directory: set `PROJECTS_DIRECTORY` and bind-mount it. Same path inside and outside
  the container is recommended (as Dockge/Dockru require) but Arcane can translate paths if
  they differ, or accept `PROJECTS_DIRECTORY=<containerPath>:<hostPath>`.
- Arcane scans the projects directory, including nested folders, and runs a filesystem
  watcher. Compose files dropped there by `stack-sync` appear as "unmanaged" projects until
  adopted in the UI.
- `.env` precedence: Arcane `TZ`/`LANG` < `.env.global` in the projects dir < project `.env`.
  `.env` is editable in the UI through a dedicated editor.
- Official CLI (`arcane`, module `github.com/getarcaneapp/arcane/cli/v2`). Checked the source
  on 2026-10-06: `projects create` and `projects update` each push one project's compose and
  `.env`, but there is no upsert, no multi-stack manifest, no dry-run/diff, and `update` does
  not start the stack. Replacing stack-sync with it would mean writing that sync layer
  ourselves, so we are not using it for deploys.
- Image updates: "Image Update Watcher" cron checks registries, an Updates page lists pending
  updates with one-click Update, and the project page has Redeploy (pull + restart) and Pull.
  Optional auto-update with per-container exclusions via compose labels
  (`com.getarcaneapp.arcane.updater=false`). Docs: https://getarcane.app/docs/docker/auto-updates
- Terminal: container exec in the browser, gated by the `containers:exec` RBAC permission.
  There is no host terminal; the maintainer closed requests for one as not planned.
- Auth: Arcane has its own login and supports OIDC. We front management UIs with TinyAuth via
  Caddy `import tinyauth`; decide whether to use Arcane's built-in login, OIDC against Pocket ID
  (see `apps/auth`), or both.

## Current state (what Dockru does today)

- Compose: `apps/dockru.yaml`. Port 5051 on the host, stacks dir `/mnt/app_config/dockru`
  bind-mounted at the same path, `DOCKRU_ENABLE_CONSOLE=true`, data at
  `/mnt/app_config/dockru/data`.
- Caddy: `infra/caddy/Caddyfile` has a `@dockru host dockru.local.kye.dev` block with
  `import tinyauth` pointing at 192.168.0.20:5051. Deploy with `just deploy sync-caddy`.
- Deployment: `stack-sync` in SSH mode. The local `~/.stack-sync.toml` (synced from Bitwarden
  by vault-sync, entry `secrets.stack-sync` in `.vault-sync.toml`) has `mode = "ssh"`,
  `host = "192.168.0.20"`, `ssh_user = "root"`, `host_dir = "/mnt/app_config/dockru"`.
  For every stack in `.stack-sync.toml` it writes `{host_dir}/{stack}/compose.yaml` plus `.env`,
  then runs `docker compose up -d` in that directory (`redeploy` adds `pull`). `sync --dry-run`
  and `diff` show changes without applying them.
- Ansible: `infra/proxmox/roles/portainer-stacks` runs `stack-sync sync` locally
  (tag `docker-stacks`, `just deploy docker-stacks [stack] [--check]`). Despite the usage text,
  the recipe always syncs every stack: the role ignores `portainer_stack_filter`, and
  `--check` skips the command task instead of previewing. For one stack or a preview, run
  `stack-sync sync <stack>` or `stack-sync sync --dry-run` from the repo root. The role
  `docker-portainer` (tag `setup-docker`) still installs Docker and Portainer on a fresh host.
- Backups: restic backs up `/tank/apps` on the Proxmox host (`infra/restic/profiles.yaml`).
  Confirm `/mnt/app_config` inside the docker LXC is a bind mount of `/tank/apps` so the new
  Arcane data dir and projects dir are covered.
- The host also runs Dozzle (`apps/dozzle.yaml`) for logs; Arcane overlaps with it, keep or
  drop later.
- Secrets in `.env` files come from Bitwarden through vault-sync; never commit `.env` files.

## Plan

Arcane gets its own directories and does not share Dockru's: data at
`/mnt/app_config/arcane/data`, projects at `/mnt/app_config/arcane/projects`. Stacks move from
`/mnt/app_config/dockru` to the Arcane projects directory by changing stack-sync's `host_dir`.
Each stack keeps the same directory name and therefore the same compose project name, so
`docker compose up -d` in the new location should take over the running containers rather than
start a second copy. No compose file in `apps/` uses relative bind mounts, so the move does not
change any volume paths.

- [x] Phase 1: Deploy Arcane alongside Dockru
  - Add `apps/arcane.yaml`: `ghcr.io/getarcaneapp/manager`, docker socket, data at
    `/mnt/app_config/arcane/data`, and `PROJECTS_DIRECTORY=/mnt/app_config/arcane/projects`
    bind-mounted at the same path inside the container. Pick a host port that is free
    (check `apps/` and the Caddyfile for used ports).
  - Register the stack in `.stack-sync.toml` and deploy with `stack-sync sync arcane`.
    It lands in Dockru's directory for now and moves with everything else in Phase 3.
  - Add a Caddy route `arcane.local.kye.dev` following the dockru block, then
    `just deploy sync-caddy`.
  - Complete first-run setup in the UI. The project list should be empty; Dockru still owns
    every stack.
  - Done 2026-10-07. `apps/arcane/arcane.yaml` (image `:v2`, ran v2.15.1), host port 3552,
    secrets in `apps/arcane/.env` (vault-sync `secrets.arcane`). Stack files live at
    `/mnt/app_config/dockru/arcane` until Phase 3.
  - Runs as root (`PUID=0`/`PGID=0`): Arcane's default UID 65532 couldn't write the projects
    dir, which sits outside `/app/data` so Arcane won't chown it. `JWT_SECRET` is deprecated
    and was removed; only `ENCRYPTION_KEY` is needed.
  - Auth: TinyAuth in front, plus Arcane OIDC against Pocket ID with auto-redirect, so one
    Pocket ID login covers both. `OIDC_MERGE_ACCOUNTS` linked the Pocket ID login to the
    default local admin (`arcane`/`arcane-admin` at first start, email changed to match).
    The merge needs `email_verified`, so the Pocket ID user must have "Email verified" on.
    Local authentication is now disabled in Arcane's settings.
- [ ] Phase 2: Move one stack and test the UI
  - Move one low-risk stack (e.g. `uptime-kuma`): sync it with a temporary stack-sync config
    that lists only that stack and sets `host_dir = "/mnt/app_config/arcane/projects"`
    (`stack-sync sync -C <file>`; a `host_dir` in an explicit `-C` file overrides
    `~/.stack-sync.toml`). Then remove `/mnt/app_config/dockru/<stack>` on the host so Dockru
    stops listing it. Confirm `docker ps` shows one set of containers for the stack, not two.
  - Until Phase 3, a full sync (including any `just deploy docker-stacks`) writes this stack
    back into Dockru's directory. Sync other stacks by name in between, or remove the old copy
    again afterwards.
  - Adopt the project in Arcane. Confirm start/stop/restart, container exec terminal, and
    Pull/Redeploy.
  - Enable the image update watcher and confirm the Updates page populates.
  - Check that Arcane did not rewrite or reformat the adopted compose file
    (`ssh root@192.168.0.20 cat /mnt/app_config/arcane/projects/<stack>/compose.yaml`).
- [ ] Phase 3: Switch stack-sync to Arcane's projects directory
  - Change `host_dir` to `/mnt/app_config/arcane/projects` in the Bitwarden secret behind
    `~/.stack-sync.toml` (vault-sync entry `secrets.stack-sync`), then refresh the local file.
  - Preview with `stack-sync sync --dry-run`, then run `just deploy docker-stacks`.
    Every stack is written to the new directory and brought up there. Confirm no duplicate
    containers, then remove the stack directories under `/mnt/app_config/dockru` (leave
    Dockru's own `data` dir until Phase 5).
  - Change an adopted project's compose locally, run `stack-sync sync <stack>`, and
    confirm Arcane shows the new compose without a manual refresh and the project stays
    adopted.
  - For an adopted stack with a `.env`, open it in Arcane's `.env` editor, redeploy it with
    stack-sync, and confirm Arcane does not regenerate or overwrite the `.env` stack-sync
    wrote (Arcane's GitOps env merge writes `.env` from `.env.git` + `project.env`; make sure
    that does not apply to non-GitOps projects).
- [ ] Phase 4: Adopt all stacks
  - Adopt every remaining project in the Arcane UI. Confirm all are running and reachable
    through Caddy.
  - Auth is decided (TinyAuth + OIDC via Pocket ID, done in Phase 1).
- [ ] Phase 5: Remove Dockru
  - Remove `apps/dockru.yaml` and its `.stack-sync.toml` entry, the Caddy `@dockru` block,
    and the `dockru.local.kye.dev` route. Stop and remove the container on the host, then
    delete `/mnt/app_config/dockru`.
  - Decide whether Dozzle stays.
- [ ] Phase 6: Fresh-host provisioning
  - Add an ansible role that installs Arcane on a new docker host as the alternative to
    `docker-portainer` (tag `setup-docker`). Update `README.md`, `CLAUDE.md`, and the
    `portainer-stacks` role naming/docs, which still describe Portainer.
- [ ] Phase 7: End-to-end test
  - New docker host, install Arcane, deploy stacks, verify. Same as `dockge.md` Phase 7.

## Open questions to verify early

1. Does Arcane's watcher re-read a project whose `compose.yaml` and `.env` are overwritten
   by `stack-sync` over SSH, and does it keep the project adopted? Checked in Phase 3.
2. Does Arcane work behind Caddy with TinyAuth forward auth, or does its WebSocket/gRPC
   traffic need a bypass (there is a closed issue about gRPC behind reverse proxies, #3413)?
   Yes (checked 2026-10-07): the UI, OIDC login, and the container exec terminal
   (WebSocket) all work behind TinyAuth with no bypass.
3. Is `/mnt/app_config` in the docker LXC the same dataset as `/tank/apps` on the Proxmox
   host, so backups cover Arcane's SQLite DB?
   Yes (checked 2026-10-07): `findmnt /mnt/app_config` on the docker host shows `tank/apps`.
