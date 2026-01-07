# GitOps Operator
# Note: Admin user and bastion are created in infrastructure, not configuration
# Configuration reads admin credentials from infrastructure state
# Using the openshift provider for simplified operator management
resource "openshift_operator" "gitops" {
  provider = openshift

  count = var.gitops_enabled && var.enable_destroy == false ? 1 : 0

  name      = "openshift-gitops-operator"
  namespace = "openshift-gitops-operator"
  channel   = "latest"
  source    = "redhat-operators"
  version   = var.gitops_operator_version != null ? var.gitops_operator_version : null

  # When version is specified, install_plan_approval must be "Manual"
  # Otherwise, use "Automatic" (default)
  install_plan_approval = var.gitops_operator_version != null ? "Manual" : "Automatic"

  labels = merge(var.labels, {
    "app.kubernetes.io/managed-by" = "Terraform"
    "app.kubernetes.io/part-of"    = data.terraform_remote_state.infrastructure.outputs.cluster_name
  })

  namespace_labels = {
    "openshift.io/cluster-monitoring" = "true"
  }

  wait_for_csv = true
  wait_timeout = "10m"

  lifecycle {
    # OpenShift automatically adds labels like "operators.coreos.com/openshift-gitops-operator.openshift-gitops-operator"
    # We should not remove those when applying our labels
    ignore_changes = [labels]
  }
}

# Loki Logging Infrastructure (optional)
# Creates S3 bucket, IAM role, K8s secret, and dedicated machine pool for Loki
# The actual LokiStack, ClusterLogForwarder, and Operators are deployed via GitOps (see gitops/ folder)
module "loki" {
  source = "../../../../modules/configuration/loki"

  count = var.loki_enabled ? 1 : 0

  cluster_id        = data.terraform_remote_state.infrastructure.outputs.cluster_id
  cluster_name      = data.terraform_remote_state.infrastructure.outputs.cluster_name
  region            = var.region
  oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn
  oidc_issuer_url   = replace(data.terraform_remote_state.infrastructure.outputs.oidc_endpoint_url, "https://", "")
  subnet_id         = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids[0]

  # Optional: Customize Loki settings
  instance_type  = var.loki_instance_type
  replicas       = var.loki_replicas
  retention_days = var.loki_retention_days

  # Optional: Disable machine pool if not using dedicated nodes
  create_machinepool = var.loki_create_machinepool

  tags = var.labels
}

# Data source to fetch the GitOps server route
# The route is created by the GitOps operator in the openshift-gitops namespace
# Note: This is the ArgoCD instance route, not the operator namespace (openshift-gitops-operator)
# The route is created automatically when the GitOps operator installs ArgoCD
# Using kubernetes_resource data source to read OpenShift Route resource
# Reference: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource
data "kubernetes_resource" "gitops_route" {
  count = var.gitops_enabled && var.enable_destroy == false && length(openshift_operator.gitops) > 0 ? 1 : 0

  api_version = "route.openshift.io/v1"
  kind        = "Route"

  metadata {
    name      = "openshift-gitops-server"
    namespace = "openshift-gitops"
  }

  # Wait for the operator to be ready and CSV to be Succeeded before trying to fetch the route
  # The route is created by the ArgoCD instance, which is deployed after the operator CSV succeeds
  depends_on = [openshift_operator.gitops]
}