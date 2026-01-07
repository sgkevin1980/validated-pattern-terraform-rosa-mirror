terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"  # Pin to 2.x to avoid breaking changes in v3
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }

  # Uncomment for remote state backend
  # backend "s3" {
  #   bucket         = "my-org-terraform-state"
  #   key            = "examples/public/configuration/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

# Read infrastructure state
data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = "../infrastructure/terraform.tfstate"
  }
}

# AWS provider
provider "aws" {
  region = var.region
}

# Kubernetes provider - uses token from oc login
provider "kubernetes" {
  host     = data.terraform_remote_state.infrastructure.outputs.api_url
  token    = var.k8s_token
  insecure = var.skip_tls_verify
}

# Helm provider - uses same auth as Kubernetes
provider "helm" {
  kubernetes {
    host     = data.terraform_remote_state.infrastructure.outputs.api_url
    token    = var.k8s_token
    insecure = var.skip_tls_verify
  }
}

# RHCS provider - needed for Loki machine pool
provider "rhcs" {
  token = var.token
}
