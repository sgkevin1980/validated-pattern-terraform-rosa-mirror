# GitOps Namespace Module Variables
# This module ONLY creates the namespace for GitOps
# The actual operator installation is done via Helm charts (gitops/01-bootstrap/)

variable "namespace" {
  description = "Namespace for the GitOps operator"
  type        = string
  default     = "openshift-gitops-operator"
  nullable    = false
}

variable "labels" {
  description = "Labels to apply to the namespace"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the cluster (for labeling)"
  type        = string
  nullable    = false
}
