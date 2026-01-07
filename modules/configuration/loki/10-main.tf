# Loki Module
# Creates all infrastructure required for Loki logging on ROSA HCP:
# - S3 bucket for log storage
# - IAM role (IRSA) for secure S3 access
# - Kubernetes secret with S3 credentials
# - Dedicated machine pool for Loki workloads

locals {
  # Auto-generate bucket name if not provided
  bucket_name = var.bucket_name != null ? var.bucket_name : "${var.cluster_name}-loki-logs"

  # Common tags
  common_tags = merge(var.tags, {
    ManagedBy   = "Terraform"
    ClusterName = var.cluster_name
    Component   = "loki"
  })
}

# =============================================================================
# S3 STORAGE
# =============================================================================

# S3 Bucket for Loki logs
resource "aws_s3_bucket" "loki" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

# Lifecycle rule for log retention
resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  count = var.retention_days > 0 ? 1 : 0

  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# =============================================================================
# IAM (IRSA - IAM Roles for Service Accounts)
# =============================================================================

# IAM Policy for Loki S3 access
resource "aws_iam_policy" "loki_s3" {
  name        = "${var.cluster_name}-loki-s3"
  description = "IAM policy for Loki to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LokiS3Access"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = [
          aws_s3_bucket.loki.arn,
          "${aws_s3_bucket.loki.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for Loki (IRSA)
resource "aws_iam_role" "loki" {
  name        = "${var.cluster_name}-loki"
  description = "IAM role for Loki service account (IRSA)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_issuer_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach S3 policy to the role
resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki_s3.arn
}

# =============================================================================
# KUBERNETES SECRET
# =============================================================================

# Note: Namespace creation is handled by ArgoCD with CreateNamespace=true
# We create the secret in the existing namespace

# Kubernetes Secret for Loki S3 credentials
# This secret is used by LokiStack to authenticate with S3 using IRSA
# Reference: https://docs.openshift.com/container-platform/latest/observability/logging/log_storage/installing-log-storage.html
resource "kubernetes_secret" "loki_s3" {
  count = var.create_kubernetes_secret ? 1 : 0

  metadata {
    name      = var.secret_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"    = "loki-s3-credentials"
      "app.kubernetes.io/part-of" = "logging-stack"
    }
  }

  type = "Opaque"

  # Required fields for LokiStack S3 storage with IRSA:
  # - bucketnames: S3 bucket name
  # - region: AWS region
  # - endpoint: S3 endpoint URL
  # - role_arn: IAM role ARN for IRSA (instead of access keys)
  data = {
    bucketnames = local.bucket_name
    region      = var.region
    endpoint    = "https://s3.${var.region}.amazonaws.com"
    role_arn    = aws_iam_role.loki.arn
  }

  # Note: Namespace must exist before secret creation
  # openshift-logging is pre-created by OpenShift or ArgoCD
}

# =============================================================================
# MACHINE POOL
# =============================================================================

# Dedicated Machine Pool for Loki
# Note: RHCS HCP machine pool uses labels for node selection
# Taints are applied via labels and PodSpec tolerations
resource "rhcs_hcp_machine_pool" "loki" {
  count = var.create_machinepool ? 1 : 0

  cluster     = var.cluster_id
  name        = var.machinepool_name
  subnet_id   = var.subnet_id
  auto_repair = true

  # Autoscaling disabled - use fixed replicas
  autoscaling = {
    enabled = false
  }

  # Fixed replicas for Loki nodes
  replicas = var.replicas

  # AWS node pool configuration
  aws_node_pool = {
    instance_type            = var.instance_type
    ec2_metadata_http_tokens = "required"
    tags                     = local.common_tags
  }

  # Labels for node selection (LokiStack uses nodeSelector with these labels)
  labels = var.node_labels

  # Note: Taints are not directly supported via rhcs_hcp_machine_pool
  # Use node labels + LokiStack nodeSelector for workload isolation
}

