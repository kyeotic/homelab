# K3OS

## Cloud Init

To enable WS2 to serve across the network a bridge must be created ([see issue](https://github.com/microsoft/WSL/issues/4150)). Run the `net.ps1` script from an Admin Powershell terminal.

```
curl http://192.168.0.20:3000/k3os
cat /etc/rancher/k3s/k3s.yaml
vat /var/lib/rancher/k3s/server/node-token
```

## Traefik and Cert-manager

This should eventually be moved into cloud-init, but for now `install-traefik` will work