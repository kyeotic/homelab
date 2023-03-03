locals {
  dns = [
    {
      name    = "nas"
      records = ["192.168.0.10"]
    },
    {
      name    = "local"
      records = ["192.168.0.11"]
    },
    {
      name    = "*.local"
      records = ["192.168.0.11"]
    }
  ]
}

data "aws_route53_zone" "kye_dev" {
  name = "kye.dev."
}

resource "aws_route53_record" "dns" {
  for_each = { for k, v in local.dns : k => v }
  zone_id  = data.aws_route53_zone.kye_dev.zone_id
  name     = "${each.value.name}.kye.dev"
  type     = "A"
  ttl      = 300
  records  = each.value.records
}
