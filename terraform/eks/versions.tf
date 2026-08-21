terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  backend "s3" {
    bucket       = "noteapp-tfstate-686062433938"
    key          = "noteapp/eks/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Cluster must exist before these two providers can authenticate against it —
# fine on a fresh `apply` since Terraform only evaluates them when a resource
# that needs them is actually applied, by which point the cluster resource
# earlier in the graph has already been created.
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Reads the app-data stack's outputs (prod + non-prod table/bucket ARNs) so
# IRSA policies here don't have to duplicate resource names by hand.
data "terraform_remote_state" "app_data" {
  backend = "s3"
  config = {
    bucket = "noteapp-tfstate-686062433938"
    key    = "noteapp/terraform.tfstate"
    region = "eu-north-1"
  }
}
