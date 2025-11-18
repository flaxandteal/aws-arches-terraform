variable "name" {
  type        = string
  description = "Environment name"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones"
}

variable "tags" {
  type    = map(string)
  default = {}
}