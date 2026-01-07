# Configuration Outputs

# =============================================================================
# LOKI OUTPUTS
# =============================================================================

output "loki_bucket_name" {
  description = "S3 bucket name for Loki logs"
  value       = var.loki_enabled ? module.loki[0].bucket_name : null
  sensitive   = false
}

output "loki_iam_role_arn" {
  description = "IAM role ARN for Loki (IRSA)"
  value       = var.loki_enabled ? module.loki[0].iam_role_arn : null
  sensitive   = false
}

output "loki_secret_name" {
  description = "Kubernetes secret name for Loki S3 credentials"
  value       = var.loki_enabled ? module.loki[0].secret_name : null
  sensitive   = false
}

output "loki_machinepool_name" {
  description = "Machine pool name for Loki nodes"
  value       = var.loki_enabled && var.loki_create_machinepool ? module.loki[0].machinepool_name : null
  sensitive   = false
}

output "loki_node_labels" {
  description = "Node labels for Loki pods (use in LokiStack nodeSelector)"
  value       = var.loki_enabled && var.loki_create_machinepool ? module.loki[0].node_labels : null
  sensitive   = false
}

# =============================================================================
# GITOPS OUTPUTS
# =============================================================================

output "gitops_operator_installed" {
  description = "Whether GitOps operator was installed"
  value       = var.loki_enabled
  sensitive   = false
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is running"
  value       = var.loki_enabled ? "openshift-gitops" : null
  sensitive   = false
}

# =============================================================================
# STATUS
# =============================================================================

output "deployment_status" {
  description = "Summary of what was deployed"
  value = var.loki_enabled ? "Loki logging deployment initiated. Check: oc get applications -n openshift-gitops" : "Loki logging not enabled. Set loki_enabled=true to deploy."
  sensitive   = false
}
