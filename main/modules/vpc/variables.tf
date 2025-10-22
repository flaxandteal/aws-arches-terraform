variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "subnet_count" { type = number }
variable "single_nat" { type = bool }
variable "ingress_cidr_blocks" { type = list(string) }
variable "nacl_ingress_cidr_blocks" { type = list(string) }
variable "common_tags" { type = map(string) }