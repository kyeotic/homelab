# obsidian-livesync

CouchDB instance for [Obsidian LiveSync](https://github.com/vrtmrz/obsidian-livesync).

## Setup

**1. Create directories on the Docker host** (one-time, before first deploy):

```bash
./setup-host.sh
```

**2. Provision the Cloudflare tunnel and Access policy** (one-time):

```bash
cd infra/dns && terraform apply
```

Then populate `.env` with the tunnel token output:

```bash
cd infra/dns && terraform output -raw livesync_tunnel_token
```

**3. Deploy the stack** via stack-sync:

```bash
stack-sync sync obsidian-livesync
```

**4. Initialize CouchDB** for LiveSync (one-time, after first deploy):

```bash
./init-couchdb.sh
```

**5. Fix CouchDB CORS headers** (one-time, after init):

```bash
./fix-cors.sh
```

## Connecting the Obsidian plugin

In the Self-hosted LiveSync plugin settings:

- **URI**: `https://livesync.kye.dev`
- **Username / Password**: values from `.env`
- **Database**: any name (created on first sync)

Under **Advanced → Custom HTTP headers**, add:

| Header | Value |
|---|---|
| `CF-Access-Client-Id` | `terraform output -raw livesync_service_token_id` |
| `CF-Access-Client-Secret` | `terraform output -raw livesync_service_token_secret` |

Cloudflare Access validates these at the edge using a **Service Auth** (`non_identity`) policy before the request reaches CouchDB. Note: Obsidian desktop shows a CORS warning during the connection test — this is a desktop-only Electron quirk and does not affect sync.