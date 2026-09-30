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

# --------------------------------------------------------------------------
# Per-environment overrides
# --------------------------------------------------------------------------
variable "dev_prebuild_cross_account_read" {
  description = "Dev prebuild bucket and KMS key the starches-ci role may read cross-account. Defaults to the dev bucket UAT reads from; set to null in environments that own their prebuild bucket (prod)."
  type = object({
    bucket_arn  = string
    kms_key_arn = string
  })
  default = {
    bucket_arn  = "arn:aws:s3:::catalina-dev-prebuild-e785373b"
    kms_key_arn = "arn:aws:kms:ap-southeast-6:510664426317:key/da7d4378-c077-44e4-bd78-f9feada02105"
  }
}

variable "catalina_build_oidc_subject" {
  description = "GitHub OIDC token sub claim trusted by the catalina-build ECR push role. Defaults to catalina-build's main branch (UAT, no GitHub Environment); prod uses the environment form, e.g. repo:tepapaatawhai@<org_id>/catalina-build@<repo_id>:environment:prod."
  type        = string
  default     = "repo:tepapaatawhai@144412126/catalina-build@1353062778:ref:refs/heads/main"
}
