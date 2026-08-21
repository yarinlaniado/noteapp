terraform {
  required_version = ">= 1.10" # needs the S3 backend's native use_lockfile support

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State bucket comes from terraform/bootstrap/ (a separate, one-time-applied
  # stack whose own state stays local — see the comment in its versions.tf).
  backend "s3" {
    bucket       = "noteapp-tfstate-686062433938"
    key          = "noteapp/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
