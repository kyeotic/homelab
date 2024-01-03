
This document details the network design for the homelab.

## Networks

| Name    | CIDR               | DHCP Start | Description            |
| ------- | ------------------ | ---------- | ---------------------- |
| Default | **192.168.0.0/22** | 30         | Default                |
| IOT     | **192.168.2.0/24** | 20         | Internet-of-things LAN |


## Static Leases (Reserved IPs)

| Name       | IP            | Description                  |
| ---------- | ------------- | ---------------------------- |
| Gateway    | 192.168.0.1   | Primary Gateway              |
| Printer    | 192.168.0.9   | Brother Printer              |
| Proxmox    | 192.168.0.10  | Promox Server                |
| TrueNAS    | 192.168.0.11  | TrueNAS Server               |
| nginx      | 192.168.0.12  | Proxmox NGINX                |
| Cockpit    | 192.168.0.13  | Cockpit LXC                  |
| HOAS       | 192.168.0.15  | Home Assistant OS            |
| Technitium | 192.168.0.16  | Technitium DNS Blocker       |
| PiHole     | 192.168.0.17  | Pi Hole DNS Blocker          |
| VPN        | 192.168.0.18  | Tailscale Router             |
| Mealie     | 192.168.0.21  | Mealie                       |
| Kye-1      | 192.168.0.100 | Tims Main PC                 |
| Kate       | 192.168.0.105 | Kate's iPhone                |
| KyeNAS     | 192.168.0.200 | Old Synology NAS, deprecated |


## Utilities


- `ipcalc`: a CLI for viewing CIDR address space. Example: `ipcalc 10.0.0.0/24` to see the IP space for that subnet.

- [Subnet Calculator](https://mxtoolbox.com/subnetcalculator.aspx) A GUI for CIDR calculations

## Warnings

Consider the following when designing

- [Subnets to avoid](https://www.reddit.com/r/homelab/comments/7u8gmo/comment/dtif3bb/?utm_source=reddit&utm_medium=web2x&context=3)


## VPN

Remote access is handled with [TailScale's Subnet Router](https://tailscale.com/kb/1019/subnets?q=route&tab=linux#advertise-subnet-routes)