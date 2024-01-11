
## Useful Links
* https://tteck.github.io/Proxmox/

## Installed Apps

| Name           | Type | IP Address   | Alias                                             |
| -------------- | ---- | ------------ | ------------------------------------------------- |
| Home Assistant | LXC  | 192.168.0.15 | [hoas&homeassistant].local.kye.dev                |
| Nginx          | LXC  | 192.168.0.12 | nginx.local.kye.dev                               |
| PiHole         | LXC  | 192.168.0.17 | http://192.168.0.17/admin/login.php               |
| Mealie         | LXC  | 192.168.0.21 | food.local.kye.dev                                |
| DDns           | LXC  | DHCP         | https://crazymax.dev/ddns-route53/install/docker/ |


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

## NAS

Install TrueNAS on VM

### Passthrough

PassThrough Devices ([Guide](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM)) and [video](https://www.youtube.com/watch?v=MkK-9_-2oko))

| Name     | Serial          | Serial ID                                   |
| -------- | --------------- | ------------------------------------------- |
| /dev/sda | S6PNNS0W105328K | ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105328K |
| /dev/sdb | S6PNNS0W105332H | ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105332H |
| /dev/sdc | S6PNNS0W105404L | ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105404L |

```
scsi1: /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105328K,size=1953514584K,serial=S6PNNS0W105328K
scsi2: /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105332H,size=1953514584K,serial=S6PNNS0W105332H
scsi3: /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PNNS0W105404L,size=1953514584K,serial=S6PNNS0W105404L
```

### Mount Shares

**In the LXC (as root)**
```
groupadd -g 10000 lxc_shares

# Different apps use different users, e.g. docker, plex, jellyfin
usermod -aG lxc_shares USERNAME
```

Shutdown the LXC

**On THe PVE Host**

```
mkdir -p /mnt/lxc_shares/NAS_NAME

# Update paths and user creds
{ echo '' ; echo '# Mount CIFS share on demand with rwx permissions for use in LXCs (manually added)' ; echo '//kye-1/SMB_NAME/ /mnt/lxc_shares/NAS_NAME cifs _netdev,x-systemd.automount,noatime,uid=100000,gid=110000,dir_mode=0770,file_mode=0770,user=media,pass=ijustwantmedia 0 0' ; } | tee -a /etc/fstab

systemctl daemon-reload

# Update the LXC_ID
{ echo 'mp0: /mnt/lxc_shares/NAS_NAME/,mp=/mnt/nas' ; } | tee -a /etc/pve/lxc/LXC_ID.conf

```

LXC maybe needs additional commands
```
adduser --disabled-password --gecos "" --home "$(pwd)" --ingroup "docker" --no-create-home --uid "1000" "docker"
```

Restart the LXC

Docker needs to use this user for the binds to work.

## Arr Stack

See [this guide](https://www.synoforum.com/resources/ultimate-starter-page-1-jellyfin-jellyseerr-nzbget-torrents-and-arr-media-library-stack.184/)

Or [this one](https://www.reddit.com/r/radarr/comments/yj4fcw/ultimate_starter_full_dockercompose_arr_media/)

This is your [usenet provider](https://www.newsgroup.ninja/en/member)

[Setup FlareSolverr](https://www.zenrows.com/blog/flaresolverr#set-up-with-prowlarr)


### ZFS Setup

Set max memory to 2Gb + (1Gb * TbOfStorage). 5.5Tb pool, rounded to 6tb = `8589934592`

To permanently change the ARC limits, add the following line to `/etc/modprobe.d/zfs.conf``:
```
options zfs zfs_arc_max=8589934592
```

Using [this guide](https://homelab.casaursus.net/a-light-weight-nas/#install-cockpit)

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


To run at boot `rc-update add docker boot`

See [this guide](https://collabnix.com/how-to-install-the-latest-version-of-docker-compose-on-alpine-linuxin-2022/)