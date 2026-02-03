
This document details the network design for the homelab.

## Networks

| Name    | CIDR               | DHCP Start | Description            |
| ------- | ------------------ | ---------- | ---------------------- |
| Default | **192.168.0.0/22** | 30         | Default                |
| IOT     | **192.168.2.0/24** | 20         | Internet-of-things LAN |


## Static Leases (Reserved IPs)

| Name         | IP              | Description                                  |
| ------------ | --------------- | -------------------------------------------- |
| Gateway      | 192.168.0.1     | Primary Gateway                              |
| Printer      | 192.168.0.9     | Brother Printer                              |
| Proxmox      | 192.168.0.10    | Promox Server                                |
| NAS          | 192.168.0.11    | Debian NAS/SMB                               |
| nginx        | 192.168.0.12    | NGINX (Deprecated for caddy)                 |
| caddy        | 192.168.0.13    | Caddy (Reverse Proxy)                        |
| Plex         | 192.168.0.14    | Plex (Deprecated, on docker now)             |
| HOAS         | 192.168.0.15    | Home Assistant OS(Deprecated, on docker now) |
| AdGuard      | 192.168.0.17    | DNS Blocker                                  |
| VPN          | 192.168.0.18    | Tailscale Router                             |
| PBS          | 192.168.0.19    | Proxmox Backup Server                        |
| Portainer    | 192.168.0.20    | Docker and Portainer                         |
| Coen's Range | 192.168.0.21-30 | Coen's IP Range for local devices            |
| Kye-1        | 192.168.0.100   | Tims Main PC                                 |
| Kate         | 192.168.0.105   | Kate's iPhone                                |
| KyeNAS       | 192.168.0.200   | Old Synology NAS, deprecated                 |
| Ionir        | 192.168.0.201   | Tims iPhone                                  |
| Kate iPhone  | 192.168.0.202   | Kates iPhone                                 |
| Coen iPhone  | 192.168.0.203   | Coens iPhone                                 |


## Utilities


- `ipcalc`: a CLI for viewing CIDR address space. Example: `ipcalc 10.0.0.0/24` to see the IP space for that subnet.

- [Subnet Calculator](https://mxtoolbox.com/subnetcalculator.aspx) A GUI for CIDR calculations

## Warnings

Consider the following when designing

- [Subnets to avoid](https://www.reddit.com/r/homelab/comments/7u8gmo/comment/dtif3bb/?utm_source=reddit&utm_medium=web2x&context=3)


## VPN

Tailscale runs on an LXC in proxmox providing a subnet router. This allows any connected Tailscale client to view the home network as if they were inside of it.

### Subnet Routing
Remote access is handled with [TailScale's Subnet Router](https://tailscale.com/kb/1019/subnets?q=route&tab=linux#advertise-subnet-routes)


```
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

tailscale up --advertise-routes=192.168.0.0/24
```

After installing tailscale you may see `Temporary failure in name resolution`. TO fix update `/etc/resolv.conf`
```
search .
nameserver 1.1.1.1
```

IF that doesn't work you may have set the container to **Network > Static** without filling in the IP Address. Either add an IP or set to DHCP

## WSL Networking Bridging

On Host, in admin powershell

```
netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=$WSL_IP
```

get the WSL IP by running `ip -c a` from WSL