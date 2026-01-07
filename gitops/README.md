# GitOps Helm Charts

This folder contains Helm charts for deploying OpenShift GitOps and Loki logging stack.

## Automated Deployment Flow

When you set `loki_enabled=true` in Terraform, everything is deployed automatically:

```
┌─────────────────────────────────────────────────────────────────┐
│  terraform apply (infrastructure)                               │
│  └─ VPC, IAM, ROSA HCP Cluster                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  terraform apply -var loki_enabled=true (configuration)        │
│                                                                 │
│  Terraform automatically:                                       │
│  ├─ 1. Creates S3 bucket for Loki logs                         │
│  ├─ 2. Creates IAM role (IRSA) for S3 access                   │
│  ├─ 3. Creates Kubernetes secret with credentials              │
│  ├─ 4. Creates dedicated machine pool for Loki                 │
│  ├─ 5. Installs GitOps operator via Helm                       │
│  └─ 6. Creates ArgoCD Applications                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  ArgoCD (Automatic - no manual intervention)                    │
│  ├─ Deploys Loki Operator                                      │
│  ├─ Deploys Cluster Logging Operator                           │
│  └─ Deploys LokiStack, ClusterLogForwarder, UIPlugin           │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Deploy infrastructure
cd clusters/examples/public/infrastructure
terraform init && terraform apply

# 2. Login to cluster
export API_URL=$(terraform output -raw api_url)
export ADMIN_USER=$(terraform output -raw admin_username)
export ADMIN_PASS=$(terraform output -raw admin_password)
oc login -u $ADMIN_USER -p $ADMIN_PASS $API_URL

# 3. Deploy Loki logging (ONE COMMAND!)
cd ../configuration
export TF_VAR_k8s_token=$(oc whoami -t)
terraform init
terraform apply -var loki_enabled=true

# 4. Verify deployment
oc get applications -n openshift-gitops
oc get lokistack -n openshift-logging
```

## What Gets Deployed

When `loki_enabled=true`:

| Component | Created By | Purpose |
|-----------|------------|---------|
| S3 Bucket | Terraform | Log storage |
| IAM Role (IRSA) | Terraform | Secure S3 access |
| K8s Secret | Terraform | S3 credentials for LokiStack |
| Machine Pool | Terraform | Dedicated nodes for Loki |
| GitOps Operator | Terraform (Helm) | Manages ArgoCD |
| ArgoCD Applications | Terraform (Helm) | Deploy Loki via GitOps |
| Loki Operator | ArgoCD | Manages LokiStack CRD |
| Cluster Logging Operator | ArgoCD | Manages log forwarding |
| LokiStack | ArgoCD | Log aggregation system |
| ClusterLogForwarder | ArgoCD | Routes logs to Loki |
| UIPlugin | ArgoCD | OpenShift Console integration |

## Folder Structure

```
gitops/
├── 01-bootstrap/                    # Deployed by Terraform via helm_release
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── operator-group.yaml      # GitOps OperatorGroup
│       ├── subscription.yaml        # GitOps Subscription
│       ├── argocd-app-loki-operators.yaml  # ArgoCD App for operators
│       └── argocd-app-loki-stack.yaml      # ArgoCD App for logging stack
│
├── 02-operators/                    # Managed by ArgoCD
│   ├── loki-operator/               # Loki Operator Helm chart
│   └── cluster-logging-operator/    # Cluster Logging Operator Helm chart
│
└── 03-logging/                      # Managed by ArgoCD
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── service-account.yaml     # ClusterLogForwarder service account
        ├── lokistack.yaml           # LokiStack CR
        ├── clusterlogforwarder.yaml # Log forwarding config
        └── uiplugin.yaml            # OpenShift Console integration
```

## Configuration Options

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `loki_enabled` | `false` | Enable full Loki deployment |
| `loki_instance_type` | `m5.4xlarge` | Instance type for Loki nodes |
| `loki_replicas` | `2` | Number of dedicated Loki nodes |
| `loki_retention_days` | `90` | Log retention in S3 |
| `loki_create_machinepool` | `true` | Create dedicated machine pool |
| `gitops_repo_url` | (GitHub) | Git repo for ArgoCD |
| `gitops_repo_revision` | `main` | Git branch/tag |

### LokiStack Sizing

Edit `gitops/03-logging/values.yaml`:

```yaml
lokistack:
  size: 1x.small  # Options: 1x.demo, 1x.extra-small, 1x.small, 1x.medium
```

### Disable Dedicated Nodes

```bash
terraform apply -var loki_enabled=true -var loki_create_machinepool=false
```

And update `gitops/03-logging/values.yaml`:
```yaml
lokistack:
  nodeSelector: {}
  tolerations: []
```

## Troubleshooting

### Check Terraform Deployment

```bash
terraform output deployment_status
```

### Check ArgoCD Applications

```bash
oc get applications -n openshift-gitops
oc describe application loki-operator -n openshift-gitops
```

### Check Operators

```bash
oc get subscriptions -A | grep -E "loki|logging"
oc get csv -A | grep -E "loki|logging"
```

### Check LokiStack

```bash
oc get lokistack -n openshift-logging
oc describe lokistack logging-loki -n openshift-logging
oc get pods -n openshift-logging
```

### Check Logs

```bash
# Collector logs
oc logs -l app.kubernetes.io/component=collector -n openshift-logging

# LokiStack component logs
oc logs -l app.kubernetes.io/component=distributor -n openshift-logging
```

### Verify S3 Access

```bash
# Check if secret exists
oc get secret loki-s3-secret -n openshift-logging -o yaml

# Check if IRSA is working (from a Loki pod)
oc exec -it deploy/logging-loki-distributor -n openshift-logging -- \
  aws sts get-caller-identity
```

## Manual Deployment (Alternative)

If you prefer manual control:

```bash
# 1. Deploy just the prerequisites via Terraform
terraform apply -var loki_enabled=false
# Then manually apply the Loki module outputs

# 2. Install GitOps manually
helm template bootstrap gitops/01-bootstrap/ \
  --set loki.enabled=true \
  --set loki.bucketName="your-bucket" \
  | oc apply -f -

# 3. Or skip ArgoCD and deploy directly
helm template loki-op gitops/02-operators/loki-operator/ | oc apply -f -
helm template logging-op gitops/02-operators/cluster-logging-operator/ | oc apply -f -
helm template logging gitops/03-logging/ | oc apply -f -
```
