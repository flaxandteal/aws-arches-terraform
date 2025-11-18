variable "name" { type = string }
variable "tags" { type = map(string) }

variable "eks_node_role_arns" {
  description = "List of EKS node IAM role ARNs (passed from EKS module)"
  type        = list(string)
}