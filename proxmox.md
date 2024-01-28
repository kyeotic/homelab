
## Useful Links
* https://tteck.github.io/Proxmox/

## Installed Apps

| Name           | Type | IP Address   | Alias                                             |
| -------------- | ---- | ------------ | ------------------------------------------------- |
| Home Assistant | LXC  | 192.168.0.15 | homeassistant.local.kye.dev                       |
| Nginx          | LXC  | 192.168.0.12 | nginx.local.kye.dev                               |
| PiHole         | LXC  | 192.168.0.17 | http://192.168.0.17/admin/login.php               |
| Mealie         | LXC  | 192.168.0.21 | food.local.kye.dev                                |
| DDns           | LXC  | DHCP         | https://crazymax.dev/ddns-route53/install/docker/ |


## Current Server Specs

| Component | Spec                       |
| --------- | -------------------------- |
| CPU       | AMD Ryzen 6-core 12-Thread |
| RAM       | 96BG DDR5 5200mhz          |

## Initial Setup

Open a shell (answer yes to reboot prompts)

```
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/post-pve-install.sh)"
```

## Web UI Port/SSL

SSL Certs

* Go to **Datacenter** > ACME
* Create an account
* Add the Challenge Plugin
* Go to **NODE** > System/Certificates
* Add an ADME Cert

To remove the port for the Proxmox Web UI follow [this guide](https://i12bretro.github.io/tutorials/0435.html).

Log into ProxMox VE, either at the console or the web UI and launch the web shell

Run the following commands
```
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


## ZFS on Proxmox Directly

Create or import the zfs pool. [This video](https://www.youtube.com/watch?v=oSD-VoloQag) can with creation.

On the host we will map
uid: 101000 (maps to LXC 1000)
gid: 110000 (maps to LXC 10000)

```
# Create the group that maps to nas_shares on the lxc
groupadd -g 110000 nas_shares

# Create the mapped user
useradd nas -u 101000 -g 110000 -m -s /bin/bash

# Move ownership to the mapped user
chown -R nas:nas_shares /tank/apps/
chown -R nas:nas_shares /tank/media_root/
chown -R nas:nas_shares /tank/nas
```

For each LXC that needs a mount

```
pct set 105 -mp0 /tank/media_root,mp=/mnt/media_root
pct set 105 -mp1 /tank/apps,mp=/mnt/app_config

# for games
pct set 110 -mp1 /tank/nas/game-saves,mp=/mnt/game-saves
```

User perms still follow [this idea](https://forum.proxmox.com/threads/tutorial-unprivileged-lxcs-mount-cifs-shares.101795/)

1. 
```
# In the LXC (run commands as root user)
groupadd -g 10000 nas_shares

# create a user in that group for docker to use (use `nas` for cockpit)
useradd docker -u 1000 -g 10000 -m -s /bin/bash

```


### GPU/Hardware Transcoding

Following [this guide](https://dustri.org/b/video-acceleration-in-jellyfin-inside-a-proxmox-container.html)

run `nano /etc/pve/lxc/105.conf` and add
```
# Needed for GPU/transcoding, check the allow c values with stat /dev/DEVICE
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 235:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/renderD128 none bind,optional,create=file
lxc.mount.entry: /dev/kfd dev/kfd none bind,optional,create=file
```

On Host Shell

```
$ cat > /etc/udev/rules.d/99-gpu-chmod666.rules << 'EOF'
KERNEL=="renderD128", MODE="0666"
KERNEL=="kfd", MODE="0666"
KERNEL=="kfd", GROUP="render", MODE="0666" 
KERNEL=="card0", MODE="0666"
EOF
$ udevadm control --reload-rules && udevadm trigger
```

Restart LXC, then follow [this guide](https://jellyfin.org/docs/general/administration/hardware-acceleration/amd#configure-with-linux-virtualization)

```
getent group render | cut -d: -f3 # 106
getent group video | cut -d: -f3 # 44
```

### User Commands

```
# List Users
cat /etc/passwd

# List Groups
getent group

# List Group Members
getent group nas_shares

# Create a group with an ID named "nas_shares"
groupadd -g 1000 nas_shares

# Delete a Group
groupdel nas_shares

# Create a user with a UID, and add it to a GID
useradd lxc_docker -u 1000 -g 1000 -m -s /bin/bash

# Add a user to a group
usermod -a -G nas_shares docker

# Delete a user
deluser nas_root

```

## Arr Stack

See [this guide](https://www.synoforum.com/resources/ultimate-starter-page-1-jellyfin-jellyseerr-nzbget-torrents-and-arr-media-library-stack.184/)
or [its source](https://github.com/geekau/media-stack)

Or [this one](https://www.reddit.com/r/radarr/comments/yj4fcw/ultimate_starter_full_dockercompose_arr_media/)

This is your [usenet provider](https://www.newsgroup.ninja/en/member)

[Setup FlareSolverr](https://www.zenrows.com/blog/flaresolverr#set-up-with-prowlarr)

Final setup with [quality profiles](https://trash-guides.info/Sonarr/sonarr-setup-quality-profiles/)


### ZFS Setup

Set max memory to 2Gb + (1Gb * TbOfStorage). 5.5Tb pool, rounded to 6tb = `8589934592`

To permanently change the ARC limits, add the following line to `/etc/modprobe.d/zfs.conf``:
```
options zfs zfs_arc_max=8589934592
```

### Samba with Cockpit

Using [this guide](https://homelab.casaursus.net/a-light-weight-nas/#install-cockpit)

```
apt update && apt dist-upgrade -y
apt install cockpit --no-install-recommends

# comment out root
nano /etc/cockpit/disallowed-users
```
Allow reverse proxy: `nano /etc/cockpit/cockpit.conf`


Installing sidecards, back in the shell
```
wget https://github.com/45Drives/cockpit-file-sharing/releases/download/v3.3.4/cockpit-file-sharing_3.3.4-1focal_all.deb
wget https://github.com/45Drives/cockpit-navigator/releases/download/v0.5.10/cockpit-navigator_0.5.10-1focal_all.deb
wget https://github.com/45Drives/cockpit-identities/releases/download/v0.1.12/cockpit-identities_0.1.12-1focal_all.deb
apt install ./*.deb -y
```

#### Cockpit Reverse Proxy

```
[WebService]
Origins = https://cockpit.local.kye.dev wss://cockpit.local.kye.dev
ProtocolHeader = X-Forwarded-Proto
```

Then the Nginx proxy config needs this in advanced

```
location / {
        # Required to proxy the connection to Cockpit
        proxy_pass https://192.168.0.11:9090;
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
    }
```

Restart with `systemctl restart cockpit.service`

### Other Stuff

or maybe

Using [this guide](https://forum.proxmox.com/threads/tutorial-unprivileged-lxcs-mount-cifs-shares.101795/)

Useful Links

- https://www.youtube.com/watch?v=Hu3t8pcq8O0
- https://bayton.org/docs/linux/lxd/mount-cifssmb-shares-rw-in-lxd-containers/
- https://www.youtube.com/watch?v=UnXxJMjW4LE
- https://jo-me.github.io/proxmox-idmap-helper/


## Moving Backups

`cp /var/lib/vz/dump/vzdump-lxc-106-2024_01_10-16_30_03.* portainer/`

## Fan Control

Start [here](https://wiki.joeplaa.com/en/tutorials/how-to-install-and-configure-fancontrol-pc)

## Docker & Docker Compose

Install

```
# The official version (25.1) has issues on debian
# The deb packaged one is 20.10 and currently works better
apt install docker.io
systemctl start docker

# Portainer
docker run -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

```

Or, [For Dockge](https://github.com/louislam/dockge)


To run at boot `rc-update add docker boot`

See [this guide](https://collabnix.com/how-to-install-the-latest-version-of-docker-compose-on-alpine-linuxin-2022/)
