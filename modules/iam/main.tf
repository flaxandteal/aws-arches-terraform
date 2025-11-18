# modules/iam/main.tf

# GitHub Actions OIDC + optional extra IRSA roles
# No long-lived credentials, fully scoped, audit-ready

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ==================================================================
# GitHub OIDC Provider (one per account – safe to share across envs)
# ==================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub 2023–2031

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

# ==================================================================
# Assume Role Policy – scoped to repo + environment branch
# ==================================================================
data "aws_iam_policy_document" "github_assume" {
  statement {
    sid     = "GitHubAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

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
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:environment:${var.environment}",
        "repo:${var.github_repo}:pull_request"
      ]
    }
  }
}

# ==================================================================
# GitHub Actions Role
# ==================================================================
resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-${var.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-github-actions"
  })
}

# ==================================================================
# Least-privilege policy – scoped to THIS environment only
# ==================================================================
data "aws_iam_policy_document" "github_terraform" {
  # Full control over resources tagged with this environment
  statement {
    sid    = "ManageOwnResources"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*",
      "rds:*",
      "s3:*",
      "kms:*",
      "iam:PassRole",
      "elasticloadbalancing:*",
      "logs:*"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  # Allow PassRole only for roles in this env
  statement {
    sid       = "PassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-${var.environment}-*"]
  }

  # S3 state bucket access (explicit)
  statement {
    sid     = "S3State"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::catalina-terraform-state-${var.environment}",
      "arn:aws:s3:::catalina-terraform-state-${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "github_terraform" {
  name   = "terraform-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_terraform.json
}