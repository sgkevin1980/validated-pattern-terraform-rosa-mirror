# Loki Module

This module creates **all infrastructure required** for running the Loki logging stack on ROSA HCP clusters.

## What This Module Creates

| Resource | Description |
|----------|-------------|
| **S3 Bucket** | Encrypted storage for Loki logs with lifecycle policies |
| **IAM Role** | IRSA role for secure pod-level S3 access |
| **IAM Policy** | Least-privilege S3 permissions |
| **K8s Secret** | S3 credentials for LokiStack |
| **Machine Pool** | Dedicated nodes (m5.4xlarge) for Loki workloads |

## Usage

```hcl
module "loki" {
  source = "../../../modules/loki"

  # Required
  cluster_id        = module.cluster.cluster_id
  cluster_name      = var.cluster_name
  region            = var.region
  oidc_provider_arn = module.iam.oidc_provider_arn
  oidc_issuer_url   = replace(module.iam.oidc_endpoint_url, "https://", "")
  subnet_id         = module.network.private_subnet_ids[0]

  # Optional: Customize settings
  instance_type  = "m5.4xlarge"  # Default
  replicas       = 2              # Default
  retention_days = 90             # Default

  tags = var.tags

  depends_on = [module.cluster]
}
```

## Integration Example

Add to your cluster configuration (e.g., `clusters/examples/public/10-main.tf`):

```hcl
# After cluster and identity_admin modules...

module "loki" {
  source = "../../../modules/loki"

  cluster_id        = module.cluster.cluster_id
  cluster_name      = var.cluster_name
  region            = var.region
  oidc_provider_arn = module.iam.oidc_provider_arn
  oidc_issuer_url   = replace(module.iam.oidc_endpoint_url, "https://", "")
  subnet_id         = module.network.private_subnet_ids[0]

  tags = var.tags

  depends_on = [module.cluster]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0 |
| rhcs | ~> 1.7 |
| kubernetes | >= 2.20 |

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| cluster_id | ROSA HCP cluster ID | `string` |
| cluster_name | Cluster name (used for resource naming) | `string` |
| region | AWS region | `string` |
| oidc_provider_arn | OIDC provider ARN for IRSA | `string` |
| oidc_issuer_url | OIDC issuer URL (without https://) | `string` |
| subnet_id | Subnet ID for machine pool | `string` |

### Optional - S3 Storage

| Name | Description | Default |
|------|-------------|---------|
| bucket_name | S3 bucket name (auto-generated if null) | `null` |
| kms_key_arn | KMS key for encryption | `null` (uses AES256) |
| retention_days | Log retention in days | `90` |

### Optional - Kubernetes

| Name | Description | Default |
|------|-------------|---------|
| namespace | K8s namespace for Loki | `"openshift-logging"` |
| service_account_name | Service account name | `"loki"` |
| create_kubernetes_secret | Create K8s secret | `true` |
| secret_name | Secret name | `"logging-loki-s3"` |

### Optional - Machine Pool

| Name | Description | Default |
|------|-------------|---------|
| create_machinepool | Create dedicated nodes | `true` |
| machinepool_name | Machine pool name | `"loki"` |
| instance_type | EC2 instance type | `"m5.4xlarge"` |
| replicas | Number of nodes | `2` |
| node_labels | Node labels | `{"node-role.kubernetes.io/loki": ""}` |
| node_taints | Node taints | NoSchedule taint |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | S3 bucket name |
| bucket_arn | S3 bucket ARN |
| iam_role_arn | IAM role ARN for IRSA |
| secret_name | K8s secret name |
| machinepool_id | Machine pool ID |
| node_labels | Labels for LokiStack nodeSelector |
| node_taints | Taints for LokiStack tolerations |

## Instance Type Recommendations

| Use Case | Instance Type | vCPU | Memory | Replicas |
|----------|--------------|------|--------|----------|
| Demo/Dev | m5.xlarge | 4 | 16 GB | 1 |
| Small | m5.2xlarge | 8 | 32 GB | 2 |
| **Production** | **m5.4xlarge** | **16** | **64 GB** | **2** |
| Large | m5.8xlarge | 32 | 128 GB | 2+ |

## Security Features

- **S3**: Public access blocked, encryption enabled, versioning enabled
- **IAM**: IRSA for secure pod-level access, least-privilege permissions
- **Nodes**: Taints prevent non-Loki workloads from scheduling

## Related

- `gitops/logging/` - Helm chart for deploying LokiStack
- `gitops/operators/loki-operator/` - Loki Operator installation

