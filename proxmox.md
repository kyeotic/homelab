
## Useful Links
* https://tteck.github.io/Proxmox/

## Installed Apps

| Name           | Type | IP Address   |
| -------------- | ---- | ------------ |
| Home Assistant | LXC  |              |
| PiHole         | LXC  | 192.168.0.16 |


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