locals {
  dns = {
    "homelab" = "192.168.0.13",
    "nas"     = "192.168.0.11",
    "local"   = "192.168.0.13",
    "*.local" = "192.168.0.13"
  }
}

data "cloudflare_zone" "kye_dev" {
  name = "kye.dev"
}

resource "cloudflare_record" "dns" {
  for_each = local.dns
  zone_id  = data.cloudflare_zone.kye_dev.id
  name     = "${each.key}"
  content  = each.value
  type     = "A"
  ttl      = 1
  proxied  = false
}
