# Docker Registry + Auto-Deploy

## Current State

All infrastructure code is implemented and deployed. The registry stack and stook webhook-router are running. What remains is **testing the stook auto-redeploy pipeline**.

● Done. Now the test workflow is:                                                                                                
                                                                                                                                 
  1. just deploy docker-stacks — deploy the updated test-echo stack (pulls from registry)                                        
  2. Edit ECHO_MESSAGE in the Dockerfile to something new                                                                        
  3. Build and push:                                                                                                             
  docker build -t docker.local.kye.dev/test-echo:latest apps/test-echo/                                                          
  docker push docker.local.kye.dev/test-echo:latest                                                                              
  4. The registry notifies stook → stook finds the webhook-router.image: "test-echo" label → calls Portainer to redeploy         
                                                                                                                                 
  You'll need to do an initial build+push before the first deploy docker-stacks so the image exists in the registry.    

### What's been done

- [x] `apps/registry.yaml` — registry:2 on port 8500 + stook webhook-router
- [x] `infra/proxmox/roles/registry-config/` — data dir + weekly GC systemd timer
- [x] `infra/proxmox/group_vars/docker/stacks.yml` — registry stack entry (env_secret_id: `a64a087d-9f21-46ee-affc-b3e30072cab0`)
- [x] `infra/proxmox/playbook.yaml` — registry-config role with tags `[setup-docker, sync-registry]`
- [x] `infra/caddy/Caddyfile` — `docker.local.kye.dev` → `192.168.0.20:8500`
- [x] `apps/test-echo.yaml` — test app using registry image with stook label
- [x] `apps/test-echo/Dockerfile` — simple nginx that returns `ECHO_MESSAGE` env var
- [x] Deployed registry stack via `just deploy docker-stacks`
- [x] Deployed caddy route via `just deploy sync-caddy`
- [x] Removed automatic orphan stack deletion from portainer-stacks role (now just reports unmanaged stacks)
- [x] portainer-stacks role now self-fetches the Portainer API key from BWS if not already set (no longer depends on docker-portainer running first)

### Key changes from original plan

- Caddy hostname is `docker.local.kye.dev` (not `registry.local.kye.dev`)
- Orphan stack removal replaced with a debug message listing unmanaged stacks
- `test-echo` stack added for testing the pipeline

## Testing To Do

### 1. Initial test-echo image push

The test-echo stack is configured to pull `docker.local.kye.dev/test-echo:latest` from the registry, but the image hasn't been pushed yet. Do the initial build+push, then deploy the stack:

```bash
docker build -t docker.local.kye.dev/test-echo:latest apps/test-echo/
docker push docker.local.kye.dev/test-echo:latest
just deploy docker-stacks -e portainer_stack_filter=test-echo
```

Verify: `curl http://192.168.0.20:8501` should return "hello from test-echo"

### 2. Test stook auto-redeploy

Change the `ECHO_MESSAGE` in `apps/test-echo/Dockerfile`, rebuild, and push:

```bash
# Edit apps/test-echo/Dockerfile — change ECHO_MESSAGE to something new
docker build -t docker.local.kye.dev/test-echo:latest apps/test-echo/
docker push docker.local.kye.dev/test-echo:latest
```

Stook should automatically detect the push (via registry notification webhook) and redeploy the test-echo stack through the Portainer API. Verify by curling `http://192.168.0.20:8501` — the response should change to the new message.

### 3. Check stook logs if redeploy doesn't happen

```bash
# On the docker host (192.168.0.20)
docker logs webhook-router
```

## Remaining Work

- [ ] Test the full push → stook → Portainer redeploy pipeline (steps 1-2 above)
- [ ] Verify stook correctly reads `webhook-router.image` label and `com.docker.compose.project` label
- [ ] Verify the registry GC timer is active: `systemctl status registry-gc.timer` on docker host
- [ ] Once testing is confirmed working, remove `test-echo` stack from `stacks.yml` and delete `apps/test-echo/` (or keep as a reference)

## Architecture Reference

```
Push image → docker.local.kye.dev (Caddy) → registry:2 (port 8500)
                                                  │
                                          notification webhook
                                                  │
                                                  ▼
                                          stook (webhook-router)
                                                  │
                                    reads Docker labels to find
                                    matching webhook-router.image
                                                  │
                                                  ▼
                                          Portainer API
                                      (redeploys the stack)
```

## Per-app auto-deploy setup

Each app that uses the registry adds one label to its compose service:

```yaml
services:
  myapp:
    image: docker.local.kye.dev/myapp:latest
    labels:
      webhook-router.image: "myapp"
```

Stook reads the stack name from the `com.docker.compose.project` label (set automatically by Docker Compose) and calls the Portainer API to redeploy the stack.
