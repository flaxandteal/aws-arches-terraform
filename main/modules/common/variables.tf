variable "name" {
  description = "Name for resources (e.g., aws-dev, aws-stage)"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "extra_tags" {
  description = "Additional tags specific to the environment"
  type        = map(string)
}