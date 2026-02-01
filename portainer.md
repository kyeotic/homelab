# Adding a New App with Auto-Redeploy

## 1. Create a Compose file

In your project repo, create a `docker-compose.yaml`:

```yaml
services:
  <app-name>:
    image: docker.local.kye.dev/<app-name>:latest
    container_name: <app-name>
    restart: unless-stopped
    ports:
      - "<host-port>:<container-port>"
    labels:
      stook: redeploy
```

The `stook: redeploy` label enables automatic redeployment when a new image is pushed to the registry.

## 2. Deploy the stack to Portainer

### Option A: Portainer UI

1. Open Portainer at `https://192.168.0.20:9443`
2. Go to **Stacks** > **Add stack**
3. Give it a name matching your app
4. Paste your compose file contents
5. Add any required environment variables
6. Click **Deploy the stack**

### Option B: Script deployment

From the homelab repo root, run:

```bash
./scripts/portainer-deploy <app-name> docker-compose.yaml [bws-secret-id]
```

The optional `bws-secret-id` is a BWS secret containing env vars in `KEY=VALUE` format (one per line). Requires: `bws`, `jq`, `curl`.

## 3. Build and deploy

Add a `justfile` to your project:

```just
app_name := "<app-name>"
registry := "docker.local.kye.dev"

deploy:
    docker build --platform linux/amd64 -t {{registry}}/{{app_name}}:latest .
    docker push {{registry}}/{{app_name}}:latest
```

Then run:

```bash
just deploy
```

This builds and pushes the image to the local registry. After the initial stack deploy, stook picks up the registry push notification and triggers a redeploy automatically.
