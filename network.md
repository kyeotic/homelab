# Network Configuration

This document details the network design for the homelab.

## Networks

| Name    | CIDR               | DHCP Start | Description            |
| ------- | ------------------ | ---------- | ---------------------- |
| Default | **192.168.0.0/22** | 30         | Default                |
| Media   | **192.168.1.0/24** | 20         | Media LAN              |
| IOT     | **192.168.2.0/24** | 20         | Internet-of-things LAN |


## Static Leases (Reserved IPs)

| Name        | IP            | Description                  |
| ----------- | ------------- | ---------------------------- |
| Gateway     | 192.168.0.1   | Primary Gateway              |
| TrueNAS     | 192.168.0.10  | TrueNAS Scale Server         |
| Traefik     | 192.168.0.11  | TrueNAS Traefik Proxy        |
| HOAS        | 192.168.0.15  | Home Assistant OS            |
| PiHole      | 192.168.0.16  | Pi Hole DNS Blocker          |
| Media Share | 192.168.1.10  | TrueNAS Media Share          |
| KyeNAS      | 192.168.1.200 | Old Synology NAS, deprecated |
| Gungnir     | 192.168.0.20  | Tims Main PC                 |
| Printer     | 192.168.0.9   | Brother Printer              |

## Utilities

- `ipcalc`: a CLI for viewing CIDR address space. Example: `ipcalc 10.0.0.0/24` to see the IP space for that subnet.
- [Subnet Calculator](https://mxtoolbox.com/subnetcalculator.aspx) A GUI for CIDR calculations

## Warnings

Consider the following when designing

- [Subnets to avoid](https://www.reddit.com/r/homelab/comments/7u8gmo/comment/dtif3bb/?utm_source=reddit&utm_medium=web2x&context=3)
