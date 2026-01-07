# GitOps Namespace Module
# This module ONLY creates the namespace for OpenShift GitOps
# The actual operator installation is done via Helm charts (gitops/01-bootstrap/)
#
# Why separate namespace creation from operator installation?
# - kubernetes_manifest has issues with CRDs and timing
# - Helm charts handle operator installation better (Subscription, InstallPlan, CSV)
# - Terraform manages the namespace in state, Helm manages the operator

locals {
  common_labels = merge(var.labels, {
    "app.kubernetes.io/managed-by" = "Terraform"
    "app.kubernetes.io/part-of"    = var.cluster_name
  })
}

# Create the GitOps operator namespace
resource "kubernetes_namespace" "gitops_operator" {
  metadata {
    name = var.namespace

    labels = merge(local.common_labels, {
      "openshift.io/cluster-monitoring" = "true"
    })
  }

  lifecycle {
    # Namespace may have additional labels added by operators
    ignore_changes = [metadata[0].annotations]
  }
}

# Create the openshift-gitops namespace (where ArgoCD instance runs)
resource "kubernetes_namespace" "gitops" {
  metadata {
    name = "openshift-gitops"

    labels = merge(local.common_labels, {
      "openshift.io/cluster-monitoring" = "true"
    })
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}
