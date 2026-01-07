# Loki Module Outputs
# Following .cursorrules: All outputs have descriptions

# =============================================================================
# S3 STORAGE OUTPUTS
# =============================================================================

output "bucket_name" {
  description = "Name of the S3 bucket for Loki logs"
  value       = aws_s3_bucket.loki.id
  sensitive   = false
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for Loki logs"
  value       = aws_s3_bucket.loki.arn
  sensitive   = false
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = var.region
  sensitive   = false
}

# =============================================================================
# IAM OUTPUTS
# =============================================================================

output "iam_role_arn" {
  description = "ARN of the IAM role for Loki (IRSA)"
  value       = aws_iam_role.loki.arn
  sensitive   = false
}

output "iam_role_name" {
  description = "Name of the IAM role for Loki"
  value       = aws_iam_role.loki.name
  sensitive   = false
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for Loki S3 access"
  value       = aws_iam_policy.loki_s3.arn
  sensitive   = false
}

# =============================================================================
# KUBERNETES SECRET OUTPUTS
# =============================================================================

output "secret_name" {
  description = "Name of the Kubernetes secret containing S3 credentials"
  value       = var.create_kubernetes_secret ? kubernetes_secret.loki_s3[0].metadata[0].name : null
  sensitive   = false
}

output "namespace" {
  description = "Kubernetes namespace where the secret is created"
  value       = var.namespace
  sensitive   = false
}

# =============================================================================
# MACHINE POOL OUTPUTS
# =============================================================================

output "machinepool_id" {
  description = "ID of the Loki machine pool (null if not created)"
  value       = var.create_machinepool ? rhcs_hcp_machine_pool.loki[0].id : null
  sensitive   = false
}

output "machinepool_name" {
  description = "Name of the Loki machine pool"
  value       = var.create_machinepool ? rhcs_hcp_machine_pool.loki[0].name : null
  sensitive   = false
}

output "instance_type" {
  description = "Instance type used for Loki nodes"
  value       = var.instance_type
  sensitive   = false
}

output "replicas" {
  description = "Number of Loki node replicas"
  value       = var.replicas
  sensitive   = false
}

output "node_labels" {
  description = "Labels applied to Loki nodes (use in LokiStack nodeSelector)"
  value       = var.node_labels
  sensitive   = false
}

output "node_taints" {
  description = "Taints applied to Loki nodes (use in LokiStack tolerations)"
  value       = var.node_taints
  sensitive   = false
}

