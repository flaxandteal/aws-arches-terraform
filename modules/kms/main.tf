# modules/kms/main.tf
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  kms_suffix = var.use_random_suffix ? "-${random_id.kms_suffix.hex}" : ""
}

resource "random_id" "kms_suffix" { #used for testing only since KMS keys of same name cannot be created repeatedly
  byte_length = 2
}

# ==================================================================
# Storage Key – EBS + RDS (one key for both)
# ==================================================================
resource "aws_kms_key" "storage" {
  description             = "${var.name} - EBS & RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.storage.json

  tags = merge(var.tags, {
    Name = "${var.name}-storage-kms"
    Use  = "ebs-rds"
  })
}

resource "aws_kms_alias" "storage" {
  name          = "alias/${var.name}-${var.environment}${local.kms_suffix}-storage"
  target_key_id = aws_kms_key.storage.key_id
}

# ==================================================================
# S3 Key
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
  name          = "alias/${var.name}-${var.environment}${local.kms_suffix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ==================================================================
# Storage key policy – SERVICE PRINCIPALS ONLY (no node ARN = no cycle)
# ==================================================================
data "aws_iam_policy_document" "storage" {
  # Root + IAM admins
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

  # Allow EC2 & EKS services (covers ALL node roles automatically)
  statement {
    sid    = "AllowEC2EKS"
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

  # Allow RDS service
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
    sid    = "AllowS3"
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