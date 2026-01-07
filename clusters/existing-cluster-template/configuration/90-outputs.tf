# Outputs for Existing Cluster Configuration

# =============================================================================
# LOKI OUTPUTS
# =============================================================================

output "loki_bucket_name" {
  description = "S3 bucket name for Loki logs"
  value       = var.loki_enabled ? module.loki[0].bucket_name : null
  sensitive   = false
}

output "loki_iam_role_arn" {
  description = "IAM role ARN for Loki IRSA"
  value       = var.loki_enabled ? module.loki[0].iam_role_arn : null
  sensitive   = false
}

output "loki_secret_name" {
  description = "Kubernetes secret name for Loki S3 credentials"
  value       = var.loki_enabled ? module.loki[0].secret_name : null
  sensitive   = false
}

output "loki_machinepool_name" {
  description = "Name of the Loki machine pool"
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
  description = "Namespace where ArgoCD is deployed"
  value       = "openshift-gitops"
  sensitive   = false
}

# =============================================================================
# DEPLOYMENT STATUS
# =============================================================================

output "deployment_status" {
  description = "Summary of what was deployed"
  value       = var.loki_enabled ? <<-EOT
    
    ============================================
    LOKI LOGGING DEPLOYMENT COMPLETE
    ============================================
    
    Terraform created:
    ✅ S3 bucket: ${module.loki[0].bucket_name}
    ✅ IAM role (IRSA): ${module.loki[0].iam_role_arn}
    ✅ Kubernetes secret: ${module.loki[0].secret_name}
    ${var.loki_create_machinepool ? "✅ Machine pool: ${module.loki[0].machinepool_name}" : "⏭️  Machine pool: Skipped"}
    ✅ GitOps operator installed
    ✅ ArgoCD Applications created
    
    ArgoCD is now deploying:
    - Cluster Observability Operator
    - Loki Operator
    - Cluster Logging Operator  
    - LokiStack
    - ClusterLogForwarder
    - UIPlugin (Logs UI)
    
    Check deployment status:
      oc get applications -n openshift-gitops
      oc get lokistack -n openshift-logging
    
    View logs in OpenShift Console:
      Observe > Logs
    
    ============================================
  EOT
  : "Loki logging not enabled. Set loki_enabled=true to deploy."
  sensitive   = false
}

# =============================================================================
# NEXT STEPS
# =============================================================================

output "next_steps" {
  description = "Commands to verify deployment"
  value       = <<-EOT
    
    === Verify Deployment ===
    
    # Check ArgoCD applications
    oc get applications -n openshift-gitops
    
    # Check LokiStack status
    oc get lokistack -n openshift-logging
    
    # Check ClusterLogForwarder status
    oc get clusterlogforwarder -n openshift-logging
    
    # Check Loki pods
    oc get pods -n openshift-logging -l app.kubernetes.io/instance=logging-loki
    
    # Check console plugins
    oc get console.operator.openshift.io cluster -o jsonpath='{.spec.plugins}'
    
  EOT
  sensitive   = false
}

