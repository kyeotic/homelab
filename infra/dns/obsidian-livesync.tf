###########################
# Obsidian LiveSync Tunnel
###########################

locals {
  livesync_full_domain = "${var.obsidian_livesync_domain}.${var.root_domain}"
}

resource "random_id" "livesync_tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "livesync" {
  account_id = local.cloudflare_account_id
  name       = "livesync-tunnel"
  secret     = random_id.livesync_tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "livesync" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.livesync.id

  config {
    ingress_rule {
      hostname = local.livesync_full_domain
      service  = "http://couchdb:5984"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "livesync" {
  zone_id = data.cloudflare_zone.kye_dev.id
  name    = var.obsidian_livesync_domain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.livesync.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

###########################
# Cloudflare Access — Service Token
###########################
# The Obsidian plugin can't do browser OAuth, so we use a service token instead.
# The plugin sends CF-Access-Client-Id and CF-Access-Client-Secret headers on every
# request; Cloudflare validates them at the edge before the request reaches CouchDB.

resource "cloudflare_zero_trust_access_application" "livesync" {
  account_id       = local.cloudflare_account_id
  name             = "Obsidian LiveSync"
  domain           = local.livesync_full_domain
  type             = "self_hosted"
  session_duration = "24h"

  cors_headers {
    allowed_methods   = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
    allowed_origins   = ["app://obsidian.md", "capacitor://localhost", "http://localhost"]
    allow_all_headers = true
    allow_credentials = true
    max_age           = 3600
  }
}

resource "cloudflare_zero_trust_access_service_token" "livesync" {
  account_id = local.cloudflare_account_id
  name       = "Obsidian LiveSync Plugin"
}

resource "cloudflare_zero_trust_access_policy" "livesync_allow" {
  account_id     = local.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.livesync.id
  name           = "Allow LiveSync service token"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.livesync.id]
  }
}

###########################
# Outputs
###########################

output "livesync_tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.livesync.tunnel_token
  sensitive = true
}

output "livesync_service_token_id" {
  value     = cloudflare_zero_trust_access_service_token.livesync.client_id
  sensitive = true
}

output "livesync_service_token_secret" {
  value     = cloudflare_zero_trust_access_service_token.livesync.client_secret
  sensitive = true
}