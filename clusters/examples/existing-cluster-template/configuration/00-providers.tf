# Provider Configuration for Existing ROSA HCP Cluster
# This configuration is designed to work with an existing cluster
# without requiring a separate infrastructure layer

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
      version = "~> 2.10"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "existing-cluster/configuration/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Cluster   = var.cluster_name
    }
  }
}

# RHCS provider for machine pool management
provider "rhcs" {
  token = var.token
}

# Kubernetes provider - uses token from oc login
provider "kubernetes" {
  host  = var.k8s_host
  token = var.k8s_token
}

# Helm provider for deploying GitOps and ArgoCD apps
provider "helm" {
  kubernetes {
    host  = var.k8s_host
    token = var.k8s_token
  }
}

