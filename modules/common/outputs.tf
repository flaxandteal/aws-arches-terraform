output "name" {
  value = var.name
}

output "common_tags" {
  value = merge(var.common_tags, var.extra_tags, { Name = var.name })
}