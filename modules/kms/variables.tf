variable "name" { type = string }
variable "environment" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "use_random_suffix" {
  description = "Whether to add a random suffix to KMS alias names (useful for ephemeral or test environments)"
  type        = bool
  default     = false
}