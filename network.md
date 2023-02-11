# Network Configuration

This document details the network design for the homelab.

## Networks

| Name    | CIDR            | Usable IPs | Description                     |
| ------- | --------------- | ---------- | ------------------------------- |
| -       | **10.0.0.0/24** | 254        | Reserved for External Use       |
| Default | **10.1.0.0/22** | 1007       | Default (10.1.0.1-10.1.3.254)   |
| Media   | **10.2.0.0/24** | 249        | Media LAN (10.2.0.1-10.2.0.254) |
| IOT     | **10.3.0.0/22** | 1007       | Media LAN (10.3.0.1-10.3.3.254) |


## Static Leases (Reserved IPs)

| Name    | IP         | Description                        |
| ------- | ---------- | ---------------------------------- |
| Gateway | 10.1.0.1   | Primary Gateway (lol, 10101)       |
| TrueNAS | 10.1.0.10  | TrueNAS Scale Server (lol, 101010) |
| KyeNAS  | 10.2.0.20  | Old Synology NAS, deprecated       |
| Gungnir | 10.1.0.101 | Tims Main PC (lol, 1010101)        |

## Utilities

- `ipcalc`: a CLI for viewing CIDR address space. Example: `ipcalc 10.0.0.0/24` to see the IP space for that subnet.
- [Subnet Calculator](https://mxtoolbox.com/subnetcalculator.aspx) A GUI for CIDR calculations

## Warnings

Consider the following when designing

- [Subnets to avoid](https://www.reddit.com/r/homelab/comments/7u8gmo/comment/dtif3bb/?utm_source=reddit&utm_medium=web2x&context=3)
