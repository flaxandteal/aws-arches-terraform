variable "name" {
  type        = string
  description = "Cluster / environment name (used as prefix)"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in the form owner/repo"
}

variable "region" {
  type        = string
  description = "AWS region"
}