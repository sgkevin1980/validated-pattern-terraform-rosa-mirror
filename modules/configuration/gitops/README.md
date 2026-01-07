# GitOps Namespace Module

This module creates the namespaces required for OpenShift GitOps.

## Important

**This module only creates namespaces.** The actual GitOps operator installation is done via Helm charts in `gitops/01-bootstrap/`.

### Why Separate Namespace from Operator?

1. **kubernetes_manifest issues**: Terraform's `kubernetes_manifest` has timing issues with CRDs
2. **Helm is better for operators**: Helm handles Subscription, InstallPlan approval, CSV waiting properly
3. **Clear separation**: Terraform manages infrastructure (namespaces), Helm manages operators

## What This Module Creates

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | `openshift-gitops-operator` | Where the operator runs |
| Namespace | `openshift-gitops` | Where ArgoCD instance runs |

## Usage

```hcl
module "gitops_namespace" {
  source = "../../../../modules/configuration/gitops"

  cluster_name = var.cluster_name
  labels       = var.labels
}
```

## After Terraform Apply

After running `terraform apply`, install the GitOps operator using Helm:

```bash
helm template bootstrap ../../../../gitops/01-bootstrap/ | oc apply -f -
```

Or let ArgoCD manage it once bootstrapped.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| namespace | GitOps operator namespace | `string` | `"openshift-gitops-operator"` |
| labels | Labels for resources | `map(string)` | `{}` |
| cluster_name | Cluster name for labeling | `string` | required |

## Outputs

| Name | Description |
|------|-------------|
| operator_namespace | GitOps operator namespace |
| gitops_namespace | ArgoCD namespace |
