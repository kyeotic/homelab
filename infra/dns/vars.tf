variable "cloudflare_account_name" {
  default = "tim@kye.dev"
}

variable "root_domain" {
  type    = string
  default = "kye.dev"
}

variable "mealie_domain" {
  description = "Domain for Mealie (e.g. cook.kye.dev)"
  type        = string
  default     = "cook"
}

variable "auth0_domain" {
  description = "Auth0 tenant domain (e.g. dev-xxx.us.auth0.com)"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 application client ID (shared by Cloudflare Access and Mealie OIDC)"
  type        = string
}

variable "auth0_client_secret" {
  description = "Auth0 application client secret (shared by Cloudflare Access and Mealie OIDC)"
  type        = string
  sensitive   = true
}
