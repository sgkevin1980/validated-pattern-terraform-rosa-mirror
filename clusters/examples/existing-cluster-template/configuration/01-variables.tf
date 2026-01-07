# Variables for Existing ROSA HCP Cluster Configuration
# These values must be provided - there are no defaults from infrastructure layer

# =============================================================================
# EXISTING CLUSTER INFORMATION (REQUIRED)
# =============================================================================

variable "cluster_id" {
  description = "ID of the existing ROSA HCP cluster. Get via: rosa describe cluster -c <name> -o json | jq -r '.id'"
  type        = string
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the existing ROSA HCP cluster"
  type        = string
  nullable    = false
}

variable "region" {
  description = "AWS region where the cluster is deployed"
  type        = string
  nullable    = false
}

# =============================================================================
# AUTHENTICATION (REQUIRED)
# =============================================================================

variable "token" {
  description = "OCM token for RHCS provider. Get via: rosa token"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "k8s_host" {
  description = "Kubernetes API server URL. Get via: oc whoami --show-server"
  type        = string
  nullable    = false
}

variable "k8s_token" {
  description = "Kubernetes bearer token. Get via: oc whoami -t"
  type        = string
  sensitive   = true
  nullable    = false
}

# =============================================================================
# OIDC CONFIGURATION FOR IRSA (REQUIRED)
# =============================================================================

variable "oidc_provider_arn" {
  description = <<-EOT
    ARN of the OIDC provider for IRSA.
    Get OIDC endpoint: rosa describe cluster -c <name> -o json | jq -r '.aws.sts.oidc_endpoint_url'
    Construct ARN: arn:aws:iam::<account-id>:oidc-provider/<oidc-endpoint-without-https>
  EOT
  type        = string
  nullable    = false
}

variable "oidc_issuer_url" {
  description = <<-EOT
    OIDC issuer URL without https:// prefix.
    Get via: rosa describe cluster -c <name> -o json | jq -r '.aws.sts.oidc_endpoint_url' | sed 's|https://||'
  EOT
  type        = string
  nullable    = false
}

# =============================================================================
# LOKI CONFIGURATION
# =============================================================================

variable "loki_enabled" {
  description = "Enable Loki logging stack deployment"
  type        = bool
  default     = true
  nullable    = false
}

variable "loki_subnet_id" {
  description = <<-EOT
    Subnet ID for Loki machine pool nodes (should be a private subnet).
    Get via: aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' --output text
  EOT
  type        = string
  nullable    = false
}

variable "loki_create_machinepool" {
  description = "Whether to create a dedicated machine pool for Loki workloads"
  type        = bool
  default     = true
  nullable    = false
}

variable "loki_instance_type" {
  description = "Instance type for Loki machine pool nodes"
  type        = string
  default     = "m5.4xlarge"
  nullable    = false
}

variable "loki_replicas" {
  description = "Number of nodes in the Loki machine pool"
  type        = number
  default     = 2
  nullable    = false
}

variable "loki_retention_days" {
  description = "Number of days to retain logs in S3"
  type        = number
  default     = 30
  nullable    = false
}

# =============================================================================
# GITOPS CONFIGURATION
# =============================================================================

variable "gitops_repo_url" {
  description = "Git repository URL containing the GitOps Helm charts"
  type        = string
  default     = "https://github.com/sgkevin1980/validated-pattern-terraform-rosa.git"
  nullable    = false
}

variable "gitops_repo_revision" {
  description = "Git branch or tag to use"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_base_path" {
  description = "Base path within the Git repository for Helm charts"
  type        = string
  default     = "gitops"
  nullable    = false
}

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to AWS resources"
  type        = map(string)
  default     = {}
  nullable    = false
}

