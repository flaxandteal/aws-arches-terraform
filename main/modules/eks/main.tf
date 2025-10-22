locals {
  tags = {}
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.name}-eks"
  cluster_version = "1.30"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  cluster_endpoint_public_access = false

  eks_managed_node_groups = {
    general = {
      min_size                      = var.min_size
      max_size                      = var.max_size
      desired_size                  = var.desired_size
      instance_types                = [var.instance_type]
      disk_size                     = 50
      subnet_ids                    = var.subnet_ids # Distribute across AZs
      additional_security_group_ids = [aws_security_group.node.id]
      launch_template = {
        ebs_kms_key_id = var.kms_key_arn
      }

      # Add lifecycle block to ignore changes
      # this should help avoid flux causing the state to become out of sync
      lifecycle = {
        ignore_changes = [
          desired_size,
          default_node_pool[0].node_count,
          metadata[0].annotations,
          # or metadata[0].labels,
          # or status, etc.
        ]
      }
    }
  }

  enable_irsa = true

  node_security_group_additional_rules = {
    ssm = {
      description = "SSM access"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
    eks = {
      description = "EKS control plane"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
    ecr = {
      description = "ECR access"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"] # Adjust if client provides specific CIDR
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, local.tags)
}

resource "aws_security_group" "node" {
  name   = "${var.name}-node-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
  tags = merge(var.common_tags, local.tags)
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.eks_admin.arn
}

resource "aws_iam_role" "eks_admin" {
  name = "${var.name}-eks-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy" "eks_admin" {
  name = "${var.name}-eks-admin-policy"
  role = aws_iam_role.eks_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}