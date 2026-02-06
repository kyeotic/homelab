###########################
# Mealie Tunnel
###########################

locals {
  mealie_full_domain = "${var.mealie_domain}.${var.root_domain}"
}

resource "random_id" "mealie_tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "mealie" {
  account_id = local.cloudflare_account_id
  name       = "mealie-tunnel"
  secret     = random_id.mealie_tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "mealie" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.mealie.id

  config {
    ingress_rule {
      hostname = local.mealie_full_domain
      service  = "http://mealie:9000"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "cook" {
  zone_id = data.cloudflare_zone.kye_dev.id
  name    = var.mealie_domain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.mealie.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

###########################
# Cloudflare Access — Auth0 IdP
###########################

resource "cloudflare_zero_trust_access_identity_provider" "auth0" {
  account_id = local.cloudflare_account_id
  name       = "Auth0"
  type       = "oidc"

  config {
    client_id     = var.auth0_client_id
    client_secret = var.auth0_client_secret
    auth_url      = "https://${var.auth0_domain}/authorize"
    token_url     = "https://${var.auth0_domain}/oauth/token"
    certs_url     = "https://${var.auth0_domain}/.well-known/jwks.json"
    scopes        = ["openid", "profile", "email"]
  }
}

###########################
# Cloudflare Access — Mealie Application
###########################

resource "cloudflare_zero_trust_access_application" "mealie" {
  zone_id          = data.cloudflare_zone.kye_dev.id
  name             = "Mealie"
  domain           = local.mealie_full_domain
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "mealie_allow" {
  zone_id        = data.cloudflare_zone.kye_dev.id
  application_id = cloudflare_zero_trust_access_application.mealie.id
  name           = "Allow Auth0 users"
  decision       = "allow"
  precedence     = 1

  include {
    login_method = [cloudflare_zero_trust_access_identity_provider.auth0.id]
  }
}

###########################
# Outputs
###########################

output "mealie_tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.mealie.tunnel_token
  sensitive = true
}
