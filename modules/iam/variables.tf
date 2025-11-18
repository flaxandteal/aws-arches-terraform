variable "name_prefix" {
  description = "Prefix for IAM role names (e.g. catalina-arches)"
  type        = string
}

variable "environment" {
  description = "Environment name – used for scoping and tagging"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (e.g. flaxandteal/catalina-arches)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}