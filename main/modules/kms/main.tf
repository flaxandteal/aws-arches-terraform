# --------------------------------------------------------------
# KMS Keys – EBS & S3
# --------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------
# Data source: EKS node role (passed from EKS module)
# ------------------------------------------------------------------
data "aws_iam_role" "node" {
  name = var.node_iam_role_name
}

# ------------------------------------------------------------------
# KMS Key – EBS
# ------------------------------------------------------------------
resource "aws_kms_key" "ebs" {
  description             = "${var.name} - EBS volume encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.ebs.json

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-ebs-kms" }
  )
}

# ------------------------------------------------------------------
# KMS Key – S3
# ------------------------------------------------------------------
resource "aws_kms_key" "s3" {
  description             = "${var.name} - S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.s3.json

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-s3-kms" }
  )
}

# ------------------------------------------------------------------
# IAM Policy – EBS
# ------------------------------------------------------------------
data "aws_iam_policy_document" "ebs" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Auto Scaling"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow EC2"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow EKS Service"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Node Instances"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.node.arn]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

# ------------------------------------------------------------------
# IAM Policy – S3
# ------------------------------------------------------------------
data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow S3 Service"
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