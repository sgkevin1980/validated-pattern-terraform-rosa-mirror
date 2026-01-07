# Cluster Outputs
output "cluster_id" {
  description = "ROSA HCP Cluster ID"
  value       = module.cluster.cluster_id
  sensitive   = false
}

output "cluster_name" {
  description = "ROSA HCP Cluster Name"
  value       = var.cluster_name
  sensitive   = false
}

output "api_url" {
  description = "Cluster API URL"
  value       = module.cluster.api_url
  sensitive   = false
}

output "console_url" {
  description = "Cluster Console URL"
  value       = module.cluster.console_url
  sensitive   = false
}

# Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
  sensitive   = false
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.network.vpc_cidr_block
  sensitive   = false
}

output "region" {
  description = "AWS region"
  value       = var.region
  sensitive   = false
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
  sensitive   = false
}

# IAM Outputs (needed by configuration module)
output "oidc_provider_arn" {
  description = "OIDC Provider ARN for IRSA"
  value       = module.iam.oidc_provider_arn
  sensitive   = false
}

output "oidc_endpoint_url" {
  description = "OIDC Endpoint URL"
  value       = module.iam.oidc_endpoint_url
  sensitive   = false
}

# Admin User Outputs (if configured)
output "admin_username" {
  description = "Admin username (if identity_admin module is enabled)"
  value       = length(module.identity_admin) > 0 ? module.identity_admin[0].admin_username : null
  sensitive   = false
}

output "admin_password" {
  description = "Admin password (if identity_admin module is enabled)"
  value       = length(module.identity_admin) > 0 ? var.admin_password : null
  sensitive   = true
}
