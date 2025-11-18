# modules/kms/main.terraform {
# ==================================================================
# Description:
# This creates per-environment CMKs for EBS, RDS, S3 and Secrets Manager
# Uses least-privilege policies, automatic rotation and tagging
# ==================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ==================================================================
# EBS + RDS Encryption Key (used by EKS nodes & RDS instances)
# ==================================================================
resource "aws_kms_key" "storage" {
  description             = "${var.name} - Storage encryption (EBS/RDS)"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  multi_region            = false

  policy = data.aws_iam_policy_document.storage.json

  tags = merge(var.tags, {
    Name = "${var.name}-storage-kms"
    Use  = "ebs-rds"
  })
}

resource "aws_kms_alias" "storage" {
  name          = "alias/${var.name}-storage"
  target_key_id = aws_kms_key.storage.key_id
}

# ==================================================================
# S3 Encryption Key
# ==================================================================
resource "aws_kms_key" "s3" {
  description             = "${var.name} - S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.s3.json

  tags = merge(var.tags, {
    Name = "${var.name}-s3-kms"
    Use  = "s3"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ==================================================================
# Combined least-privilege policy for EBS/RDS key
# ==================================================================
data "aws_iam_policy_document" "storage" {
  # Account root + admins
  statement {
    sid    = "EnableRootAndAdmins"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow EKS nodes (via node role) to use for EBS
  statement {
    sid    = "AllowEKSNodesEBS"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.eks_node_role_arns
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  # Allow RDS service to use the key
  statement {
    sid    = "AllowRDS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

# ==================================================================
# S3 key policy
# ==================================================================
data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "EnableRootAndAdmins"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3Service"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}