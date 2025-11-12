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
  }

  # cluster_enabled_log_types = [
  #   "api", "audit", "authenticator", "controllerManager", "scheduler"
  # ]
  # cloudwatch_log_group_retention_in_days = var.log_retention_days

  eks_managed_node_groups = {
    main = {
      ami_type                   = "AL2023_ARM_64_STANDARD"
      instance_types             = [var.node_group.instance_type]
      min_size                   = var.node_group.min_size
      max_size                   = var.node_group.max_size
      desired_size               = var.node_group.desired_size
      enable_bootstrap_user_data = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
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