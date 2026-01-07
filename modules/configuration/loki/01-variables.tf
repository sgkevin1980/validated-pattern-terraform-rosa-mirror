# Loki Module Variables
# This module creates all infrastructure required for Loki logging:
# - S3 bucket for log storage
# - IAM role (IRSA) for S3 access
# - Kubernetes secret for Loki credentials
# - Dedicated machine pool for Loki workloads

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_id" {
  description = "ID of the ROSA HCP cluster"
  type        = string
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the ROSA HCP cluster (used for resource naming)"
  type        = string
  nullable    = false
}

variable "region" {
  description = "AWS region for the S3 bucket"
  type        = string
  nullable    = false
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA (from IAM module output)"
  type        = string
  nullable    = false
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (from IAM module output, without https://)"
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet ID where the Loki machine pool nodes will be deployed"
  type        = string
  nullable    = false
}

# =============================================================================
# S3 STORAGE CONFIGURATION
# =============================================================================

variable "bucket_name" {
  description = "Name of the S3 bucket for Loki logs (if null, auto-generated as {cluster_name}-loki-logs)"
  type        = string
  default     = null
  nullable    = true
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 bucket encryption (if null, uses AES256)"
  type        = string
  default     = null
  nullable    = true
}

variable "retention_days" {
  description = "Number of days to retain logs in S3 (0 for no expiration)"
  type        = number
  default     = 90
  nullable    = false

  validation {
    condition     = var.retention_days >= 0
    error_message = "Retention days must be 0 or greater."
  }
}

# =============================================================================
# KUBERNETES SECRET CONFIGURATION
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace where Loki will be deployed"
  type        = string
  default     = "openshift-logging"
  nullable    = false
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for Loki"
  type        = string
  default     = "loki"
  nullable    = false
}

variable "create_kubernetes_secret" {
  description = "Whether to create the Kubernetes secret for Loki S3 credentials"
  type        = bool
  default     = true
  nullable    = false
}

variable "secret_name" {
  description = "Name of the Kubernetes secret for Loki S3 credentials"
  type        = string
  default     = "logging-loki-s3"
  nullable    = false
}

# =============================================================================
# MACHINE POOL CONFIGURATION
# =============================================================================

variable "create_machinepool" {
  description = "Whether to create a dedicated machine pool for Loki"
  type        = bool
  default     = true
  nullable    = false
}

variable "machinepool_name" {
  description = "Name of the machine pool for Loki"
  type        = string
  default     = "loki"
  nullable    = false
}

variable "instance_type" {
  description = "EC2 instance type for Loki nodes (m5.4xlarge recommended for production)"
  type        = string
  default     = "m5.4xlarge"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][0-9]+[a-z]?\\..*$", var.instance_type))
    error_message = "Instance type must be a valid AWS EC2 instance type format."
  }
}

variable "replicas" {
  description = "Number of Loki nodes (2 recommended for HA)"
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition     = var.replicas >= 1
    error_message = "At least 1 replica is required."
  }
}

variable "node_labels" {
  description = "Labels to apply to the Loki nodes"
  type        = map(string)
  default = {
    "node-role.kubernetes.io/loki" = ""
  }
  nullable = false
}

variable "node_taints" {
  description = "Taints to apply to the Loki nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "node-role.kubernetes.io/loki"
      value  = ""
      effect = "NoSchedule"
    }
  ]
  nullable = false
}

# =============================================================================
# COMMON CONFIGURATION
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}

