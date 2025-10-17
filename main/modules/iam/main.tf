locals {
  tags = {}
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

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

resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy" "github_terraform" {
  name   = "${var.name}-github-terraform"
  role   = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:*",
          "eks:*",
          "rds:*",
          "s3:*",
          "ecr:*",
          "kms:*",
          "secretsmanager:*",
          "iam:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "alb_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_arn, "https://", "")}:aud"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_arn, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_assume.json
  tags               = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

data "aws_iam_policy_document" "pod_s3_ecr_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_arn, "https://", "")}:aud"
      values   = ["system:serviceaccount:default:app-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_arn, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:app-sa"]
    }
  }
}

resource "aws_iam_role" "pod_s3_ecr" {
  name               = "${var.name}-pod-s3-ecr"
  assume_role_policy = data.aws_iam_policy_document.pod_s3_ecr_assume.json
  tags               = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy" "pod_s3_ecr" {
  name   = "${var.name}-pod-s3-ecr"
  role   = aws_iam_role.pod_s3_ecr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.s3_bucket}", "arn:aws:s3:::${var.s3_bucket}/*"]
      },
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_repository
      }
    ]
  })
}