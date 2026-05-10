locals {
  tags = {}
}

data "aws_region" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  endpoint_public_access = true

  access_entries = {
    admin = {
      principal_arn = var.eks_admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  addons = {
    vpc-cni = {
      most_recent       = true
      before_compute    = true
      resolve_conflicts = "OVERWRITE"
    }

    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }

  # cluster_enabled_log_types = [
  #   "api", "audit", "authenticator", "controllerManager", "scheduler"
  # ]
  # cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Allow control plane to reach istiod webhook (port 15017) on nodes
  node_security_group_additional_rules = {
    istio_webhook = {
      description                   = "Control plane to istiod webhook"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # Default node-to-node rule only covers 1025-65535 (ephemeral ports).
    # Istio ingressgateway listens on 80/443, so cross-node kube-proxy
    # forwarding to those ports gets blocked without these rules.
    ingress_http_from_nodes = {
      description = "Node to node HTTP (for ingress gateway)"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
    ingress_https_from_nodes = {
      description = "Node to node HTTPS (for ingress gateway)"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      self        = true
    }
  }

  eks_managed_node_groups = {
    main = {
      ami_type                   = "AL2023_x86_64_STANDARD"
      instance_types             = [var.node_group.instance_type]
      min_size                   = var.node_group.min_size
      max_size                   = var.node_group.max_size
      desired_size               = var.node_group.desired_size
      enable_bootstrap_user_data = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100  # Match Catalyst Cloud docker_volume_size
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = var.ebs_kms_key_arn != "" ? var.ebs_kms_key_arn : null
            delete_on_termination = true
          }
        }
      }

      depends_on = ["vpc-cni"]
    }
  }

  tags = merge(
    var.common_tags,
    local.tags,
    {
      GitHubRepo = var.github_repo
    }
  )
}

# IAM role for EBS CSI driver (IRSA)
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "null_resource" "delay_destroy" {
  triggers = {
    cluster = module.eks.cluster_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 30" # Wait for node drain
  }
}

output "cluster_name" {
  value       = var.name
  description = "EKS cluster name (same as cluster_id)"
}


output "cluster_id" {
  value       = module.eks.cluster_id
  description = "EKS cluster ID (internal)"
}

output "node_iam_role_name" {
  value       = module.eks.eks_managed_node_groups["main"].iam_role_name
  description = "Name of the EKS node IAM role"
}

output "node_iam_role_arn" {
  value       = module.eks.eks_managed_node_groups["main"].iam_role_arn
  description = "ARN of the EKS node IAM role"
}

output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "Security group ID for EKS worker nodes"
}

output "cluster_security_group_id" {
  value       = module.eks.cluster_security_group_id
  description = "Security group ID for EKS control plane"
}