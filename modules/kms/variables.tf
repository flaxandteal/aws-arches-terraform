variable "name" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "node_iam_role_name" {
  type        = string
  description = "Name of the EKS node IAM role"
}