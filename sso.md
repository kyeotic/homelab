# SSO audit: Pocket ID / TinyAuth across `apps/`

Written 2026-10-07. Goal: move as many Docker apps as possible off their own local login and onto
the Pocket ID login (`apps/auth`). Status below was checked against the compose files, the
Caddyfile, and each app's live config on the docker host (192.168.0.20).

## Two ways an app can use Pocket ID

1. **Native OIDC.** The app is an OIDC client of Pocket ID (`https://auth.local.kye.dev`). The app
   keeps its own users and roles, but you log in through Pocket ID. Example: Arcane. Each app needs
   its own client in Pocket ID, and the client ID and secret go in the stack's `.env`.
2. **TinyAuth forward-auth gate.** Caddy's `import tinyauth` (or `import gated-arr`) sends every
   request to TinyAuth, which requires a Pocket ID session. The app's own login is then turned off
   or set to trust the proxy. Examples: the *arr apps and Dozzle. This works for any web UI, but it
   breaks clients that can't do a browser login: mobile apps, API clients, and the docker CLI.
   Those paths have to skip the gate, the way `gated-arr` handles `/api/*`.

Prefer native OIDC where an app supports it. A forward-auth gate only covers the Caddy hostname,
so gated apps also need their raw ports locked down (next section). An app that does OIDC itself
stays protected on its raw port.

## Raw ports: the `docker-firewall` role

A forward-auth gate protects the hostname, not the app. Every app also publishes its port on
192.168.0.20, so an app with its own login turned off is open at `http://192.168.0.20:<port>`.

Tested 2026-10-07, before the fix, from a LAN machine with no session and no special headers:

| Path | Result |
| --- | --- |
| `https://tv.local.kye.dev/`, with or without a fake `Remote-User` header | 401 (gate works) |
| `http://192.168.0.20:8989/` (Sonarr), and the same for Radarr, Lidarr, Prowlarr, Readarr, Bazarr, Listenarr | **200, full UI** |
| Sonarr `/initialize.json` on the raw port | **Returns the API key** |
| Bazarr page on the raw port | **Contains its API key** |
| `http://192.168.0.20:8084/` (Dozzle) | 401, but **200 with a fake `Remote-User` header** |
| `http://192.168.0.20:3552/api/environments` (Arcane) | 401 (Arcane's own OIDC login) |
| The same ports over IPv6 (`fd1a:2936:c768:4520:be24:11ff:febf:5bea`) | Open as well |

The fix is the `docker-firewall` role (tags `setup-docker`, `sync-firewall`). It installs
`/etc/nftables.d/port-gate.nft` and a `port-gate.service` unit that loads it at boot. The rules
live in their own nftables table, `inet port_gate`, so they don't touch Docker's tables and
survive Docker restarts. On `eth0`, the ports in `docker_firewall_gated_ports` (in
`roles/docker-firewall/defaults/main.yml`) accept IPv4 only from Caddy (192.168.0.13). Every other
source, and all IPv6, gets a TCP reset. Two chains are needed:

- **forward**: IPv4 connections to a published port are DNATed to the container. The rule matches
  the port the client dialed (`ct original proto-dst`), not the container port.
- **input**: IPv6 connections go through Docker's userland proxy on the host, and so do connections
  to host-network apps. The `DOCKER-USER` iptables chain never sees these, which is why this role
  uses its own nftables table.

Gated today: Sonarr 8989, Radarr 7878, Lidarr 8686, Prowlarr 9696, Readarr 8787, Bazarr 6767,
Listenarr 4545, Dozzle 8084. qBittorrent is deliberately not on the list. Arcane is left off on
purpose: it does its own login (its API returns 401 without a session), and its raw port 3552 is
the way in when Caddy, TinyAuth or Pocket ID is down. OIDC login needs the Caddy hostname, so on the
raw port only Arcane's local password login works.

Tested after applying:

- From the LAN: every gated port is refused, on IPv4 and IPv6. qBittorrent (8200) and Uptime Kuma
  (5566) still answer.
- From Caddy: every gated port answers. Through Caddy, the hostnames still return 401 without a
  session, and `/ping` still skips the gate.
- From containers: Prowlarr → `sonarr:8989`, Prowlarr → `192.168.0.20:8989` and Jellyseerr →
  `192.168.0.20:7878` all still connect. Container traffic arrives on a Docker bridge, not `eth0`.
  The docker host itself and host-network containers (Home Assistant) are not affected either.

Things to know:

- Anything on the LAN that used a raw port, such as a phone app (nzb360, LunaSea) set to
  `192.168.0.20:8989`, must use the hostname instead, e.g. `https://tv.local.kye.dev`.
  `gated-arr` lets `/api/*` through the gate, so API-key clients still work there.
- When you turn off an app's own login and rely on the gate, add its port to
  `docker_firewall_gated_ports` in the same change, then run `just deploy sync-firewall`.
- Restarting `nftables.service` runs `flush ruleset` from `/etc/nftables.conf`, which removes both
  Docker's rules and this table. Afterwards, run `systemctl restart docker` and
  `systemctl reload port-gate`.
- To turn the gate off temporarily: `systemctl stop port-gate`. To see it: `nft list table inet port_gate`.

## Summary

| App | Route | Today | Target |
| --- | --- | --- | --- |
| Arcane | arcane | ✅ Native OIDC + gate | Done |
| Dozzle | dozzle | ✅ Gate, `forward-proxy` auth | Done |
| Sonarr / Radarr / Lidarr / Prowlarr / Readarr | tv / movies / music / prowl / reader | ✅ `gated-arr`, auth = External | Done |
| Bazarr | subs | ✅ Gate, auth = none | Done |
| Listenarr | listenarr | ✅ Gate, auth off | Done |
| Uptime Kuma | kuma | ⚠️ Gate **and** its own login | Turn off Kuma's login |
| Syncthing | syncthing | ⚠️ Gate **and** a GUI user/password | Remove the GUI user/password |
| code-server (HA stack) | code | ⚠️ Gate **and** `PASSWORD` | Remove `PASSWORD` |
| qBittorrent | qbit | ❌ **No gate, no login** (see below) | Add the gate |
| Audiobookshelf | audiobooks | 🔶 Local login only | Native OIDC |
| Calibre-Web-Automated | calibre | 🔶 Local login only | Native OIDC (or header login) |
| Beszel | beszel | 🔶 Local password only | Native OIDC |
| Mealie | cook (public: cook.kye.dev) | 🔶 Native OIDC, but against **Auth0** | Decision needed (see below) |
| Jellyseerr | jellyseer | ⏳ Plex login | Wait for Seerr to ship OIDC |
| Home Assistant | homeassistant | ⏳ Local login | Community integration only, optional |
| SABnzbd | none | No route, no login | Optional: add a gated route |
| Plex, Scrypted, Docker registry | plex, scrypted, docker | ⛔ Can't use either method | Keep as is |

✅ already on Pocket ID · ⚠️ gated, but you log in twice · ❌ open · 🔶 supports OIDC, not enabled · ⏳ not supported yet / add-on only · ⛔ not supported

## Already on Pocket ID

- **Arcane.** Native OIDC (`OIDC_*` in `apps/arcane/arcane.yaml`) with auto-redirect and
  `OIDC_MERGE_ACCOUNTS`, plus the TinyAuth gate.
- **Dozzle.** `DOZZLE_AUTH_PROVIDER: forward-proxy` reads `Remote-User`/`Remote-Email` from
  TinyAuth, plus the gate.
- **Sonarr, Radarr, Lidarr, Prowlarr, Readarr.** `import gated-arr`. On the host, each
  `config.xml` has `<AuthenticationMethod>External</AuthenticationMethod>`. `/api/*`, `/feed/*` and
  `/ping` skip the gate, and the app checks its API key on those paths.
- **Bazarr.** Gated, with `/api/*` skipping the gate. On the host, `auth.type` in `config.yaml` is
  `null`, so Bazarr has no login of its own.
- **Listenarr.** Gated. On the host, `config.json` has `"AuthenticationRequired": "false"`.

## Gated, but you still log in twice (quick wins)

These apps are already behind TinyAuth, but their own login is still on. None of them support OIDC,
so the fix is to turn off their login and rely on the gate.

Whenever you turn off one of these logins, add the app's port to `docker_firewall_gated_ports` at
the same time (see "Raw ports" above). Otherwise the app is open on its raw port.

- **Uptime Kuma.** Kuma's `disableAuth` setting is not set, so its login is still on. Fix:
  Settings → Security → Disable Auth, and gate port 5566. Check first: push monitors (`/api/push/*`), badges
  (`/api/badge/*`) and public status pages (`/status/*`) already go through the gate today. If
  anything outside the browser calls those paths through `kuma.local.kye.dev`, give them a
  skip-the-gate matcher like `gated-arr` has.
- **Syncthing.** The GUI still has user `kyeotic` and a password. Fix: clear the GUI user and
  password in Settings → GUI, and gate port 8384. Syncthing will show a "GUI has no password"
  warning. Syncthing uses host networking, which the role's input chain covers.
- **code-server** (`homeassistant-code-server` in `apps/home-assistant/home-assistant.yaml`).
  `PASSWORD=${CODE_SERVER_PASSWORD}` is set. Fix: remove `PASSWORD`. The linuxserver image runs
  with no login when neither `PASSWORD` nor `HASHED_PASSWORD` is set. Then drop
  `CODE_SERVER_PASSWORD` from the `.env`, and gate port 12321. This one matters most, because the
  container runs as root (`PUID=0`) and has a terminal.

## Open today: qBittorrent

`qbit.local.kye.dev` has no `import tinyauth`. On the host, `qBittorrent.conf` has
`WebUI\AuthSubnetWhitelist=192.168.0.0/24` with the whitelist enabled. Caddy (192.168.0.13) is
inside that subnet, so every request through Caddy skips qBittorrent's login. The UI is effectively
open to anyone on the LAN or Tailscale.

qBittorrent has no OIDC. Fix: add `import tinyauth` to the `@qbit` handle and keep the subnet
whitelist, so you only log in once. The *arr apps and `qbittorrent-port` reach qBittorrent
directly, not through Caddy, so the gate doesn't affect them. A mobile qBittorrent app pointed at
`qbit.local.kye.dev` would stop working.

## Support OIDC, not enabled yet

Setup is the same for each: create an OIDC client in Pocket ID with the callback URL below, put the
client ID and secret in the stack's `.env` (or the app's UI), and leave local login on until a
Pocket ID login works. Pocket ID publishes client guides for all three at
https://pocket-id.org/docs/client-examples.

- **Audiobookshelf.** Native OIDC, configured in Settings → Authentication. On the host, the only
  active auth method is `local`. Callbacks:
  `https://audiobooks.local.kye.dev/auth/openid/callback` and
  `https://audiobooks.local.kye.dev/auth/openid/mobile-redirect`. The second one is for the mobile
  app, which supports OIDC. Set "Match existing users by" to email or username so your current
  account carries over. Don't gate this route with TinyAuth, because the mobile apps use its API.
- **Calibre-Web-Automated.** Admin → Edit Basic Configuration → Login type: Use OAuth, with the
  generic provider pointed at Pocket ID's discovery URL. Callback:
  `https://calibre.local.kye.dev/login/generic/authorized`. Today it uses standard login
  (`config_login_type = 0`), and "allow reverse proxy header login" is already on. That gives a
  second option: gate the route with TinyAuth and set the header name to `Remote-User`, which
  TinyAuth already sends. Either way, check how OPDS, KOReader and Kobo sync log in before you turn
  off local passwords, because those clients use HTTP basic auth or tokens.
- **Beszel.** Beszel is built on PocketBase, which has OAuth2/OIDC: in the PocketBase admin, go to
  Collections → users → Options → OAuth2 and add an OIDC provider. On the host, today
  `passwordAuth` is on and `oauth2` is off. Callback: `https://beszel.local.kye.dev/api/oauth2-redirect`.
  Pocket ID must return a verified email, so turn on "Emails Verified" in Pocket ID. Once a Pocket ID
  login works, set `DISABLE_PASSWORD_AUTH=true` on the hub to hide the password form. The
  `beszel-agent` uses its own key and is not affected.

### Mealie: needs a decision

Mealie already uses native OIDC with auto-redirect, but against Auth0. Switching it to Pocket ID
only means changing `OIDC_CONFIGURATION_URL` (to
`https://auth.local.kye.dev/.well-known/openid-configuration`), the client ID and secret, and
`OIDC_PROVIDER_NAME`. Mealie matches users by email (`OIDC_USER_CLAIM: email`), so existing
accounts carry over if the emails match. Callback: `https://cook.kye.dev/login`.

The problem: Mealie is public at `cook.kye.dev` through a Cloudflare tunnel, but
`auth.local.kye.dev` resolves publicly to 192.168.0.13, a private address. Anyone not on the LAN
or Tailscale would be redirected to a login page they can't reach. The options:

- Keep Auth0 for Mealie.
- Expose Pocket ID publicly, for example as another Cloudflare tunnel hostname. This puts the
  login service for the whole homelab on the internet.
- Accept that Mealie login only works on the LAN or Tailscale.

## Not supported yet, or only through an add-on

- **Jellyseerr.** No OIDC in a stable release. Jellyseerr merged into Seerr (`seerr-team/seerr`),
  and OIDC (PR #2715) is still only in the `preview-new-oidc` image. Logins go through Plex for now.
  Once a Seerr release includes OIDC, switch the image to Seerr and add a Pocket ID client.
- **Home Assistant.** No built-in OIDC. The community integration `hass-oidc-auth` (installed
  through HACS) adds a Pocket ID login. HACS is not installed (`custom_components/` is empty). A
  TinyAuth gate is not an option, because it would break the companion app and API access. Low
  priority: it is an add-on to keep updated, and a broken add-on would lock you out of HA.

## Can't use Pocket ID

- **Plex.** Logins only go through plex.tv accounts.
- **Scrypted.** Has its own login and no OIDC. Its HomeKit, Home Assistant and mobile clients
  couldn't get through a TinyAuth gate either.
- **Docker registry** (`apps/registry.yaml`). The docker CLI can only use basic auth or token auth,
  so neither OIDC nor a forward-auth gate works. **Separate problem:** the registry has no auth at
  all right now and has `REGISTRY_STORAGE_DELETE_ENABLED: "true"`, so anyone on the LAN or Tailscale
  can push and delete images through `docker.local.kye.dev`. Adding `htpasswd` auth would fix that.
- **SABnzbd.** No OIDC and no Caddy route, and it has no login set today. If you want a hostname for
  it, add a gated route with `/api` skipping the gate, as `gated-arr` does.
- **Pocket ID and TinyAuth.** These are the login services themselves. Never gate them (see the
  comment on `(tinyauth)` in the Caddyfile).

No web UI, so nothing to do: gluetun, qbittorrent-port, qbittools, flaresolverr, unpackerr,
recyclarr, matter-server, wyoming-whisper, wyoming-piper, beszel-agent, ffmpeg, and the game
servers (not deployed).

## Suggested order

1. Quick wins: add the gate to qBittorrent, and turn off the second login in Uptime Kuma, Syncthing
   and code-server.
2. Native OIDC for Beszel, Audiobookshelf and Calibre-Web-Automated.
3. Decide what to do with Mealie.
4. Revisit Jellyseerr when Seerr ships OIDC. Home Assistant only if the second login really bothers
   you.
5. Separately: add auth to the registry. (The raw ports are done, see "Raw ports" above.)

## Sources

- Pocket ID client guides (Audiobookshelf, Calibre-Web-Automated, Beszel):
  https://pocket-id.org/docs/client-examples
- Audiobookshelf OIDC: https://audiobookshelf.org/guides/oidc_authentication
- Seerr OIDC status: https://github.com/seerr-team/seerr/discussions/2721,
  https://github.com/seerr-team/seerr/pull/1505
