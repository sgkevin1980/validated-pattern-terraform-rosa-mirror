# Existing ROSA HCP Cluster Configuration Template

This template enables you to deploy GitOps and Loki logging stack to an **existing** ROSA HCP cluster without needing to manage the cluster infrastructure through Terraform.

## Prerequisites

1. An existing ROSA HCP cluster
2. `rosa` CLI installed and logged in
3. `oc` CLI installed and logged in to the cluster
4. `aws` CLI configured with appropriate permissions
5. Terraform >= 1.5.0

## Quick Start

### Step 1: Copy the Template

```bash
# Create a directory for your cluster
CLUSTER_NAME="my-existing-cluster"
cp -r clusters/existing-cluster-template clusters/${CLUSTER_NAME}
cd clusters/${CLUSTER_NAME}/configuration
```

### Step 2: Gather Required Information

Run these commands to get the required values:

```bash
# Set your cluster name
CLUSTER_NAME="your-cluster-name"

# Get cluster ID
CLUSTER_ID=$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.id')
echo "cluster_id = \"$CLUSTER_ID\""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get OIDC endpoint and construct ARN
OIDC_ENDPOINT=$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.aws.sts.oidc_endpoint_url')
OIDC_ISSUER=$(echo $OIDC_ENDPOINT | sed 's|https://||')
echo "oidc_issuer_url = \"$OIDC_ISSUER\""
echo "oidc_provider_arn = \"arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER}\""

# Get Kubernetes API URL
K8S_HOST=$(oc whoami --show-server)
echo "k8s_host = \"$K8S_HOST\""

# Get a private subnet ID
SUBNET_ID=$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.aws.subnet_ids[0]')
VPC_ID=$(aws ec2 describe-subnets --subnet-ids $SUBNET_ID --query 'Subnets[0].VpcId' --output text)
PRIVATE_SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" --query 'Subnets[0].SubnetId' --output text)
echo "loki_subnet_id = \"$PRIVATE_SUBNET\""

# Get region
REGION=$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.region.id')
echo "region = \"$REGION\""
```

### Step 3: Create terraform.tfvars

Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with the values from Step 2
```

### Step 4: Export Authentication Tokens

```bash
# OCM token for ROSA API
export TF_VAR_token=$(rosa token)

# Kubernetes token for cluster access
export TF_VAR_k8s_token=$(oc whoami -t)
```

### Step 5: Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `loki_enabled` | Enable Loki logging stack | `true` |
| `loki_create_machinepool` | Create dedicated machine pool | `true` |
| `loki_instance_type` | Instance type for Loki nodes | `m5.4xlarge` |
| `loki_replicas` | Number of Loki nodes | `2` |
| `loki_retention_days` | Log retention period | `30` |
| `gitops_repo_url` | Git repository for GitOps charts | See default |
| `gitops_repo_revision` | Git branch/tag | `main` |

## What Gets Deployed

When `loki_enabled = true`, Terraform will:

1. **Create AWS Resources:**
   - S3 bucket for log storage
   - IAM role with IRSA for S3 access
   - Kubernetes secret with S3 credentials

2. **Create Machine Pool (if enabled):**
   - Dedicated nodes for Loki workloads
   - Labels for nodeSelector targeting

3. **Install Operators via GitOps:**
   - OpenShift GitOps Operator
   - Cluster Observability Operator
   - Loki Operator
   - Cluster Logging Operator

4. **Deploy Logging Stack:**
   - LokiStack
   - ClusterLogForwarder
   - UIPlugin (Logs UI in Console)

## Verify Deployment

```bash
# Check ArgoCD applications
oc get applications -n openshift-gitops

# Check LokiStack
oc get lokistack -n openshift-logging

# Check ClusterLogForwarder
oc get clusterlogforwarder -n openshift-logging

# Check Loki pods
oc get pods -n openshift-logging -l app.kubernetes.io/instance=logging-loki

# Check console plugins
oc get console.operator.openshift.io cluster -o jsonpath='{.spec.plugins}'
```

## Cleanup

To remove the logging stack:

```bash
terraform destroy
```

**Note:** This will only remove resources managed by Terraform. Your existing ROSA cluster will remain intact.

## Troubleshooting

### ArgoCD can't access Git repository

If you're using a private Git repository, you need to configure ArgoCD with credentials:

```bash
# Create repository secret
oc create secret generic my-repo \
  --from-literal=url=https://github.com/your-org/your-repo.git \
  --from-literal=username=your-username \
  --from-literal=password=your-token \
  --from-literal=type=git \
  -n openshift-gitops

# Label for ArgoCD
oc label secret my-repo argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

### IRSA authentication errors

If Loki pods can't access S3, verify:

1. The OIDC provider ARN is correct
2. The service account name matches (`logging-loki`)
3. The IAM trust policy is correct:

```bash
aws iam get-role --role-name <cluster-name>-loki --query 'Role.AssumeRolePolicyDocument'
```

### Machine pool nodes not ready

Wait 10-15 minutes for nodes to be provisioned. Check status:

```bash
rosa list machinepools -c <cluster-name>
oc get nodes -l node-role.kubernetes.io/loki
```

