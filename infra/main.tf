terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = "~> 2.5"
  }
  backend "s3" {
    bucket = "terraform-remote-902498034412"
    key    = "homelab"
    region = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}
