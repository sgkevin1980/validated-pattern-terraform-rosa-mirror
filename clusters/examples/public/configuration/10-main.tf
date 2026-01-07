# Configuration Module
# When loki_enabled=true, this automatically:
# 1. Creates Loki prerequisites (S3, IAM, secret, machinepool)
# 2. Installs GitOps operator via Helm
# 3. Creates ArgoCD Applications that deploy Loki operators and stack

locals {
  gitops_chart_path = "${path.module}/../../../../gitops"
}

# =============================================================================
# LOKI INFRASTRUCTURE (Prerequisites)
# =============================================================================
# Creates S3 bucket, IAM role, K8s secret, and dedicated machine pool for Loki
# This MUST complete before GitOps can deploy LokiStack
module "loki" {
  source = "../../../../modules/configuration/loki"

  count = var.loki_enabled ? 1 : 0

  cluster_id        = data.terraform_remote_state.infrastructure.outputs.cluster_id
  cluster_name      = data.terraform_remote_state.infrastructure.outputs.cluster_name
  region            = var.region
  oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn
  oidc_issuer_url   = replace(data.terraform_remote_state.infrastructure.outputs.oidc_endpoint_url, "https://", "")
  subnet_id         = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids[0]

  # Loki storage settings
  retention_days = var.loki_retention_days

  # Loki machine pool settings
  create_machinepool = var.loki_create_machinepool
  instance_type      = var.loki_instance_type
  replicas           = var.loki_replicas

  tags = var.labels
}

# =============================================================================
# WAIT FOR MACHINE POOL NODES
# =============================================================================
# Machine pool creation is fast, but EC2 instances take 10-15 minutes to provision
# Wait for nodes to be ready before deploying LokiStack (which has nodeSelector)

resource "time_sleep" "wait_for_machinepool_nodes" {
  count = var.loki_enabled && var.loki_create_machinepool ? 1 : 0

  depends_on = [module.loki]

  # Wait 12 minutes for EC2 instances to provision and join the cluster
  # Machine pool creates 2 replicas of m5.4xlarge nodes
  create_duration = "720s"
}

# =============================================================================
# GITOPS BOOTSTRAP
# =============================================================================
# Installs OpenShift GitOps operator and creates ArgoCD Applications
# The ArgoCD Applications will automatically deploy Loki operators and stack

# Step 1: Install GitOps Operator
resource "helm_release" "gitops_operator" {
  count = var.loki_enabled ? 1 : 0

  name             = "gitops-operator"
  chart            = "${local.gitops_chart_path}/01-bootstrap"
  namespace        = "openshift-gitops-operator"
  create_namespace = true

  # Only install the operator first (disable Loki apps initially)
  set {
    name  = "loki.enabled"
    value = "false"
  }

  # Wait for the operator to be deployed
  wait    = true
  timeout = 600

  # Wait for machine pool nodes if creating dedicated nodes
  depends_on = [module.loki, time_sleep.wait_for_machinepool_nodes]
}

# Step 2: Wait for GitOps operator to be ready before creating ArgoCD Applications
# This uses a time_sleep to allow the operator to create the ArgoCD instance
resource "time_sleep" "wait_for_gitops" {
  count = var.loki_enabled ? 1 : 0

  depends_on      = [helm_release.gitops_operator]
  create_duration = "120s"
}

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

  depends_on = [time_sleep.wait_for_gitops]
}
