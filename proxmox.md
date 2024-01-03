
## Useful Links
* https://tteck.github.io/Proxmox/

## Installed Apps

| Name           | Type | IP Address   | Alias                                             |
| -------------- | ---- | ------------ | ------------------------------------------------- |
| Home Assistant | LXC  | 192.168.0.15 | [hoas&homeassistant].local.kye.dev                |
| Nginx          | LXC  | 192.168.0.12 | nginx.local.kye.dev                               |
| PiHole         | LXC  | 192.168.0.16 | http://192.168.0.16/admin/login.php               |
| Mealie         | LXC  | 192.168.0.21 | food.local.kye.dev                                |
| DDns           | LXC  | DHCP         | https://crazymax.dev/ddns-route53/install/docker/ |


## PiHole

To exlude a device go to **Clients** > **Add** (MAC Address),  then set **Group Assignment** to **none**

## Nginx

Using [this guide](https://medium.com/@denzity/ssl-certificates-for-proxmox-using-aws-route53-the-easy-way-e8dfe0b0dbfa)

Required adding the route53 plugin to LXC Install, using [this fork](https://github.com/kyeotic/Proxmox/blob/main/ct/nginxproxymanager.sh).

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kyeotic/Proxmox/main/ct/nginxproxymanager.sh)"
```

This still didn't work, so I opened a LXC Console and ran

```
python3 -m pip install --no-cache-dir certbot-dns-route53
```

To remove the port for the Proxmox Web UI follow [this guide](https://i12bretro.github.io/tutorials/0435.html).


```
    Log into ProxMox VE, either at the console or the web UI and launch the web shell
    Run the following commands
    # add the ip tables rule
    /sbin/iptables -F
    /sbin/iptables -t nat -F
    /sbin/iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8006
    # install iptables-persistent
    apt install iptables-persistent -y
    When prompted, select Yes to save current IPv4 rules > Press Enter
    When prompted, select Yes to save current IPv6 rules > Press Enter
    Open a web browser and navigate to https://DNSorIP to verify the 443 to 8006 redirect is working
    Reboot the ProxMox host
    Once the host has rebooted, test that the web UI is still reachable without specifying the port (:8006)

```

### Home Assistant

To get home assistant working the `/var/lib/docker/volumes/hass_config/_data/configurations.yaml` needs this. (Easily edit with ssh by [enabling it](https://github.com/tteck/Proxmox/discussions/385#discussioncomment-3283416))

```
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - 192.168.0.12
```

The Nginx proxy path must also have *Websocket Support* Enabled.

### Cockpit

Requires special NGINX config

```
location / {
      # Required to proxy the connection to Cockpit
        proxy_pass https://192.168.0.13:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Required for web sockets to function
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Pass ETag header from Cockpit to clients.
        # See: https://github.com/cockpit-project/cockpit/issues/5239
        gzip off;

        proxy_buffering off;
        proxy_buffer_size 16k;
        proxy_busy_buffers_size 24k;
        proxy_buffers 64 4k;
}
```

as well as custom config in cockpit `nano /etc/cockpit/cockpit.conf`

```
[WebService]
Origins = https://cockpit.local.kye.dev wss://cockpit.local.kye.dev
ProtocolHeader = X-Forwarded-Proto
```

## NAS / Cockpit

Using [this guide](https://homelab.casaursus.net/a-light-weight-nas/#install-cockpit)

or maybe

Using [this guide](https://forum.proxmox.com/threads/tutorial-unprivileged-lxcs-mount-cifs-shares.101795/)

Useful Links

- https://www.youtube.com/watch?v=Hu3t8pcq8O0
- https://bayton.org/docs/linux/lxd/mount-cifssmb-shares-rw-in-lxd-containers/
- https://www.youtube.com/watch?v=UnXxJMjW4LE
- https://jo-me.github.io/proxmox-idmap-helper/

## Fan Control

Start [here](https://wiki.joeplaa.com/en/tutorials/how-to-install-and-configure-fancontrol-pc)

## Docker & Docker Compose

See [this guide](https://collabnix.com/how-to-install-the-latest-version-of-docker-compose-on-alpine-linuxin-2022/)