# --------------------------------------------------------------
# Data source – current AWS account
# --------------------------------------------------------------
data "aws_caller_identity" "current" {}

# --------------------------------------------------------------
# GitHub Actions OIDC provider
# --------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub OIDC thumbprint (2024‑2025)
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-github-oidc" }
  )
}

# --------------------------------------------------------------
# Assume‑role policy for GitHub Actions
# --------------------------------------------------------------
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

# --------------------------------------------------------------
# IAM role for GitHub Actions
# --------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-github-actions-role" }
  )
}

# --------------------------------------------------------------
# Least‑privilege Terraform policy
# --------------------------------------------------------------
data "aws_iam_policy_document" "github_terraform" {
  # Core EC2 (VPC, subnets, instances)
  statement {
    sid    = "EC2Core"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway"
    ]
    resources = ["*"]
  }

  # EKS
  statement {
    sid       = "EKS"
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  # IAM PassRole (scoped to own roles)
  statement {
    sid       = "IAMPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/${var.name}-*"]
  }

  # S3 – state bucket only
  statement {
    sid     = "S3State"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::tf-state-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::tf-state-${data.aws_caller_identity.current.account_id}/*"
    ]
  }

  # KMS – only for EBS/S3 encryption
  statement {
    sid       = "KMS"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${var.region}.amazonaws.com",
        "ec2.${var.region}.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy" "github_terraform" {
  name   = "${var.name}-github-terraform"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_terraform.json
}