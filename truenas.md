# TrueNAS Setup

## Jellyfin

* ACL needed to be added for `apps` user with recursive application
* For some reason the Community episodes I encoded wont play in swiftfin, but other videos will

## Home Assistant OS (VM)

I used [this guide](https://community.home-assistant.io/t/installing-haos-in-a-vm-on-truenas-scale-bluefin-edition/511393), which required `sudo` on the `qemu-img` command. Make sure to hit **Trust Guest Filters** in the VM setup under _Network Options_ to enable the hostname access `homeassistant.local:8213`.

There was a lot of trouble setting this up, but it was because of bad network config.

## Network

We want a dedicated IP for the NAS and a separate dedicated IP for the Apps/Node so that we can use standard ports for the NAS Web UI and Traefik.

I'm using `x.0.10` for the NAS and `x.0.11` for the Apps/NodeIp

To do this we assign an alias for both to the primary network interface, then go to ** System Settings > General > GUI > Settings ** and bind the Web Interface IP to the `x.10`.

Then go to ** Apps > Settings > Advanced Settings** and bind the Node IP to `x.11`.

I also setup AWS Route 53 DNS for `nas.kye.dev` `local.kye.dev` and `*.local.kye.dev` routing to the respective IPs

### DDNS

Dynamic DNS is provided by [CrazymaxDDNS](https://crazymax.dev/ddns-route53/install/docker/) running in Docker in TrueNAS. There is [a problem](https://www.truenas.com/community/threads/docker-unable-to-provide-environment-variables-einval.108324/) providing configuration as ENV VARS so it is being provided as a yaml file for now. This should be changed when possible. This is currently being handled by wrapping the image with a custom one in `ddns/Dockerfile` in order to set the `SCHEDULE` variable. It is deployed to the docker registry in TrueNAS.

The creds come from a **ddns** user in AWS with a restrictive IAM policy. This policy is defined in `infra/ddns-role`.

### Zerotier

Using the TrueCharts ZeroTier app, with the Kyeotek network: `b15644912e20851f`.

You also need to enable **System Settings > Advanced > Sysctll** and set.

| Var                                | Value | Enabled |
| ---------------------------------- | ----- | ------- |
| `net.ipv4.ip_forward`              | `1`   | `true`  |
| `net.ipv4.conf.all.src_valid_mark` | `1`   | `true`  |

See [this forum](https://www.truenas.com/community/threads/unable-to-use-zerotier-with-scale.105268/) post for more details.

## Traefik 

Used [this guide](https://truecharts.org/charts/enterprise/traefik/how-to) to setup. Since we have a separate IP already setup we can use 80/443 for the web entrypoints without changing the TrueNAS Web GUI ports.

## Certificates

Make sure System and Node IP setup are done.


Setup [ACME Authenticator](https://www.truenas.com/docs/scale/scaletutorials/credentials/certificates/settingupletsencryptcertificates/). Requried DNS for `local.kye.dev`.

Encountered this error, which required `root` and `admin` to get email address in their User Settings.

```
middlewared.service_exception.ValidationErrors: [EINVAL] name: Please configure an email address for any local administrator user which will be used with the ACME server
```

After fixing the bad system time I was able to get a cert challenge completed.