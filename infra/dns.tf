locals {
  dns = {
    "homelab" = ["192.168.0.10"],
    "nas"     = ["192.168.0.11"],
    "local"   = ["192.168.0.13"],
    "*.local" = ["192.168.0.13"],
    "hoas"    = ["192.168.0.15"]
  }
}

data "aws_route53_zone" "kye_dev" {
  name = "kye.dev."
}

resource "aws_route53_record" "dns" {
  for_each = local.dns
  zone_id  = data.aws_route53_zone.kye_dev.zone_id
  name     = "${each.key}.kye.dev"
  type     = "A"
  ttl      = 300
  records  = each.value
}
