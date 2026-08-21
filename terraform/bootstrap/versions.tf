terraform {
  required_version = ">= 1.10" # needs the S3 backend's native use_lockfile support

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Deliberately no backend block: this stack creates the state bucket, so at
  # the time it first runs, there is nowhere remote for its own state to live.
  # Its state stays local (terraform.tfstate in this directory) — back that
  # file up outside git, since it's the only record of this bucket's identity.
}

provider "aws" {
  region = var.aws_region
}
