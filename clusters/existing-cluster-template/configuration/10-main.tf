# Main Configuration for Existing ROSA HCP Cluster
# Deploys GitOps and Loki logging stack

locals {
  # Path to GitOps Helm charts (relative to Terraform module)
  gitops_chart_path = "${path.module}/../../../gitops"
}

# =============================================================================
# LOKI INFRASTRUCTURE
# =============================================================================

# Create Loki prerequisites: S3 bucket, IAM role, K8s secret, machine pool
module "loki" {
  source = "../../../modules/configuration/loki"
  count  = var.loki_enabled ? 1 : 0

  # Cluster information
  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  region       = var.region

  # OIDC for IRSA
  oidc_provider_arn = var.oidc_provider_arn
  oidc_issuer_url   = var.oidc_issuer_url

  # Machine pool configuration
  create_machinepool = var.loki_create_machinepool
  subnet_id          = var.loki_subnet_id
  instance_type      = var.loki_instance_type
  replicas           = var.loki_replicas

  # S3 configuration
  retention_days = var.loki_retention_days

  # Tags
  tags = var.tags
}

# =============================================================================
# GITOPS OPERATOR
# =============================================================================

# Step 1: Install OpenShift GitOps Operator
resource "helm_release" "gitops_operator" {
  count = var.loki_enabled ? 1 : 0

  name             = "gitops-operator"
  chart            = "${local.gitops_chart_path}/01-bootstrap"
  namespace        = "openshift-gitops-operator"
  create_namespace = true

  # Don't deploy Loki apps yet - just the operator
  set {
    name  = "loki.enabled"
    value = "false"
  }

  wait    = true
  timeout = 600

  depends_on = [module.loki]
}

# =============================================================================
# WAIT FOR RESOURCES
# =============================================================================

# Step 2: Wait for GitOps operator to be ready
resource "time_sleep" "wait_for_gitops" {
  count = var.loki_enabled ? 1 : 0

  depends_on      = [helm_release.gitops_operator]
  create_duration = "120s"
}

# Wait for machine pool nodes to be ready (12 minutes)
resource "time_sleep" "wait_for_machinepool_nodes" {
  count = var.loki_enabled && var.loki_create_machinepool ? 1 : 0

  depends_on      = [module.loki]
  create_duration = "720s"
}

# =============================================================================
# ARGOCD APPLICATIONS
# =============================================================================

# Step 3: Deploy ArgoCD Applications for Loki
resource "helm_release" "loki_apps" {
  count = var.loki_enabled ? 1 : 0

  name             = "loki-apps"
  chart            = "${local.gitops_chart_path}/01-bootstrap"
  namespace        = "openshift-gitops-operator"
  create_namespace = false

  # Enable Loki applications
  set {
    name  = "loki.enabled"
    value = "true"
  }

  # Pass Loki configuration from Terraform outputs
  set {
    name  = "loki.bucketName"
    value = module.loki[0].bucket_name
  }

  set {
    name  = "loki.region"
    value = var.region
  }

  # Git repository settings
  set {
    name  = "git.repoURL"
    value = var.gitops_repo_url
  }

  set {
    name  = "git.revision"
    value = var.gitops_repo_revision
  }

  set {
    name  = "git.basePath"
    value = var.gitops_base_path
  }

  wait    = true
  timeout = 300

  depends_on = [time_sleep.wait_for_gitops, time_sleep.wait_for_machinepool_nodes]
}

