# modules/kms/main.tf

# Per-environment CMKs – NO circular dependency with EKS

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ==================================================================
# 1. Storage Key – EBS + RDS (same key – AWS best practice)
# ==================================================================
resource "aws_kms_key" "storage" {
  description             = "${var.name} - EBS & RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  # Broad but safe policy – allows root + AWS services + EKS nodes (even if not yet created)
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
# 2. S3 Key
# ==================================================================
resource "aws_kms_key" "s3" {
  description             = "${var.name} - S3 encryption"
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
# Storage Key Policy – safe even when EKS doesn't exist yet
# ==================================================================
data "aws_iam_policy_document" "storage" {
  # 1. Full admin for account root + any IAM admins
  statement {
    sid    = "RootAndAdmins"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # 2. Allow EC2/EKS services (covers node roles even if not created yet)
  statement {
    sid    = "AllowEC2AndEKS"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "eks.amazonaws.com"
      ]
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

  # 3. Allow RDS service
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
# S3 Key Policy – simple and safe
# ==================================================================
data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "RootAndAdmins"
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