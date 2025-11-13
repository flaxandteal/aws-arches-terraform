variable "name" { type = string }
variable "common_tags" { type = map(string) }

variable "github_repo" { type = string }
variable "eks_admin_principal_arn" { type = string }
variable "ebs_kms_key_arn" {
  type        = string
  default     = ""
  description = "KMS key ARN for EBS encryption (optional)"
}
variable "cluster_version" { type = string }

variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "control_plane_subnet_ids" { type = list(string) }

variable "node_group" {
  type = object({
    instance_type = string
    desired_size  = number
    min_size      = number
    max_size      = number
  })
}

variable "log_retention_days" { type = number }
