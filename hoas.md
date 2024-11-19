# Home Assistant

Installed with: https://tteck.github.io/Proxmox/#home-assistant-os-vm

## Initial Setup

- Dedicated IP Address
  - HomeAssistent webUI at Settings -> System -> Network -> configure Network Interfaces -> enpos18 -> IPv4 -> Static
- Allow reverse proxy (install VS Code Plugin)



### Reverse Proxy Setup

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - 192.168.0.13 # must match caddy
```

The Nginx proxy path must also have *Websocket Support* Enabled.


## Plugins

- Studio Code Server
- AirSonos
- Matter Server