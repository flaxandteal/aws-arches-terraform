locals {
  tags = {}
}

resource "aws_kms_key" "data" {
  description         = "${var.name} data encryption key"
  enable_key_rotation = true
  tags                = merge(var.common_tags, local.tags)
}

resource "aws_kms_key" "secrets" {
  description         = "${var.name} secrets key"
  enable_key_rotation = true
  tags                = merge(var.common_tags, local.tags)
}

resource "aws_kms_key" "ecr" {
  description         = "${var.name} ECR key"
  enable_key_rotation = true
  tags                = merge(var.common_tags, local.tags)
}