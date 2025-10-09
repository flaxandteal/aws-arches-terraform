variable "environment" {
  description = "Environment name"
  type        = string
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