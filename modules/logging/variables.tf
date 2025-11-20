variable "name" {
  type = string
}

variable "environment" {
  type    = string
  default = "logs"
}

variable "account_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}