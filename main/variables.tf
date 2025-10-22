variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "name" {
  description = "Name for resources (e.g., aws-dev, aws-stage)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for the environment"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo for OIDC (e.g., 'org/repo')"
  type        = string
  default     = "your-org/your-repo" # Customize
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project    = "aws-cloud"
    ManagedBy  = "Terraform"
    CostCenter = "IT"
  }
}

variable "extra_tags" {
  description = "Additional tags specific to the environment"
  type        = map(string)
  default     = {}
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks for security group ingress"
  type        = list(string)
}

variable "nacl_ingress_cidr_blocks" {
  description = "CIDR blocks for NACL ingress"
  type        = list(string)
}

variable "subnet_count" {
  description = "Number of subnets per AZ"
  type        = number
}

variable "lifecycle_transition_days" {
  description = "Days before transitioning S3 objects"
  type        = number
}

variable "lifecycle_storage_class" {
  description = "S3 lifecycle storage class"
  type        = string
}

variable "clusters" {
  description = "EKS cluster settings"
  type = object({
    instance_type      = string
    desired_size       = number
    min_size           = number
    max_size           = number
    log_retention_days = number
  })
}

variable "db_class" {
  description = "RDS instance class or Aurora serverless configuration"
  type        = string
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
}

variable "db_storage" {
  description = "RDS allocated storage in GB (ignored for serverless)"
  type        = number
}

variable "db_backup_retention" {
  description = "RDS backup retention period in days"
  type        = number
}