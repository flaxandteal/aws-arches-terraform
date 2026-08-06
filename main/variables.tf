# --------------------------------------------------------------------------
# Common
# --------------------------------------------------------------------------
variable "region" { type = string }
variable "name" { type = string }

# Already passed in as TF_VAR_environment by catalina-aws-deploy's
# terraform-deploy.yml, but was previously unused here (no matching
# variable declared) - needed for the github_actions_deploy role's OIDC
# trust condition, which is scoped per GitHub Environment (uat, prod, ...).
variable "environment" {
  type        = string
  description = "Deployment environment name - must match the GitHub Environment used in the OIDC trust condition (e.g. uat, prod)."
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------
# This branch consumes an existing, externally-managed VPC (shared "publicApps"
# VPC, owned by a separate CDK stack) instead of creating its own.
variable "vpc_id" { type = string }

variable "app_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for EKS nodes and control plane"
}

variable "data_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for RDS"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs (ingress load balancers)"
  default     = []
}

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
variable "eks_admin_principal_arn" { type = string }

variable "cluster_version" { type = string }

variable "clusters" {
  type = object({
    instance_type      = string
    desired_size       = number
    min_size           = number
    max_size           = number
    log_retention_days = number
  })
}

variable "github_repo" { type = string }

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
variable "lifecycle_transition_days" {
  description = "Days before transitioning S3 objects"
  type        = number
}

variable "lifecycle_storage_class" {
  description = "S3 lifecycle storage class"
  type        = string
}

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
variable "db_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention" {
  type    = number
  default = 1
}