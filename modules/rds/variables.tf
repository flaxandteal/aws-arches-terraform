variable "name" {
  type        = string
  description = "Cluster/environment name prefix"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (at least 2 AZs)"
}

variable "eks_sg_id" {
  type        = string
  description = "EKS node security group ID"
}

variable "db_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance class (use 'db.serverless' for Aurora Serverless)"
}

variable "db_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GB (standard RDS only)"
}

variable "db_multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ (standard RDS only)"
}

variable "db_backup_retention" {
  type        = number
  default     = 1
  description = "Backup retention in days"
}

variable "kms_key_arn" {
  type        = string
  default     = ""
  description = "KMS key ARN for Secrets Manager (optional)"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment (dev/stage/prod) - used for apply_immediately"
}