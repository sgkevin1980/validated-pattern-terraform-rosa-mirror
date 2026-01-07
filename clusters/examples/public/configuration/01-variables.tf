# Configuration Variables
# These variables configure the Day-2 operations: GitOps and Loki

# =============================================================================
# RHCS PROVIDER CONFIGURATION
# =============================================================================

variable "token" {
  description = <<EOF
  Red Hat Cloud Services (RHCS) offline token for OCM API access.
  Required for creating machine pools via the RHCS provider.

  Get your token from: https://console.redhat.com/openshift/token

  Can be provided via:
  - Environment variable: TF_VAR_token
  EOF
  type        = string
  sensitive   = true
  nullable    = false
}

# =============================================================================
# KUBERNETES PROVIDER CONFIGURATION
# =============================================================================

variable "k8s_token" {
  description = <<EOF
  Kubernetes bearer token for cluster authentication.
  Automatically obtained by Makefile via 'oc login' using admin username/password from infrastructure state.

  Can be provided via:
  - Environment variable: TF_VAR_k8s_token
  - Automatically set by Makefile from infrastructure credentials
  EOF
  type        = string
  sensitive   = true
  nullable    = false
}

variable "skip_tls_verify" {
  description = "Skip TLS verification for Kubernetes API connection (not recommended for production)"
  type        = bool
  default     = false
  nullable    = false
}

variable "region" {
  description = "AWS region (should match infrastructure)"
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "labels" {
  description = "Labels to apply to Kubernetes resources"
  type        = map(string)
  default     = {}
  nullable    = false
}

# =============================================================================
# LOKI LOGGING CONFIGURATION
# =============================================================================
# When loki_enabled=true, Terraform automatically:
# 1. Creates Loki prerequisites (S3, IAM, secret, machinepool)
# 2. Installs GitOps operator
# 3. Creates ArgoCD Applications that deploy Loki operators and stack

variable "loki_enabled" {
  description = "Enable Loki logging - automatically sets up prerequisites, GitOps, and deploys Loki via ArgoCD"
  type        = bool
  default     = false
  nullable    = false
}

variable "loki_instance_type" {
  description = "EC2 instance type for Loki dedicated nodes"
  type        = string
  default     = "m5.4xlarge"
  nullable    = false
}

variable "loki_replicas" {
  description = "Number of Loki dedicated nodes"
  type        = number
  default     = 2
  nullable    = false
}

variable "loki_retention_days" {
  description = "Log retention in days for S3 bucket"
  type        = number
  default     = 90
  nullable    = false
}

variable "loki_create_machinepool" {
  description = "Whether to create a dedicated machine pool for Loki"
  type        = bool
  default     = true
  nullable    = false
}

# =============================================================================
# GITOPS CONFIGURATION
# =============================================================================
# These settings configure where ArgoCD finds the Helm charts

variable "gitops_repo_url" {
  description = "Git repository URL containing the Helm charts for ArgoCD"
  type        = string
  default     = "https://github.com/rh-mobb/validated-pattern-terraform-rosa.git"
  nullable    = false
}

variable "gitops_repo_revision" {
  description = "Git branch or tag to use"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_base_path" {
  description = "Path to gitops folder in the repository"
  type        = string
  default     = "gitops"
  nullable    = false
}
