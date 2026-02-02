terraform {
  required_version = "~> 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "terraform-remote-902498034412"
    key    = "homelab"
    region = "us-west-2"
  }
}

provider "cloudflare" {}
