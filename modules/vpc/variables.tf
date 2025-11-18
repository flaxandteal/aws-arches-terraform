# ./modules/vpc/variables.tf
variable "name" {
  type        = string
  description = "Full cluster name (e.g. arches-prod)"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags to add on top of the ones from the label module"
}