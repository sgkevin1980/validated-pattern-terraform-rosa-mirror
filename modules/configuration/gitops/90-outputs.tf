# GitOps Namespace Module Outputs

output "operator_namespace" {
  description = "Name of the GitOps operator namespace"
  value       = kubernetes_namespace.gitops_operator.metadata[0].name
  sensitive   = false
}

output "gitops_namespace" {
  description = "Name of the openshift-gitops namespace (where ArgoCD runs)"
  value       = kubernetes_namespace.gitops.metadata[0].name
  sensitive   = false
}
