# modules/eks/main.tf
# Fully private EKS cluster – exactly as per your architecture doc

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0" # Latest stable as of Nov 2025

  name    = local.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id          = var.vpc_id
  subnet_ids      = var.private_subnet_ids

  # ==================================================================
  # FULLY PRIVATE – no public access allowed
  # ==================================================================
  endpoint_private_access = true
  endpoint_public_access  = true #sji todo

  # Optional: dedicated subnets for control plane (more isolation)
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # ==================================================================
  # Addons – only what you need
  # ==================================================================
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

  # ==================================================================
  # Node Group – single managed group (ARM or x86)
  # ==================================================================
  eks_managed_node_groups = {
    main = {
      name           = "main"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      ami_type                   = var.node_ami_type # e.g. AL2023_ARM_64_STANDARD
      enable_bootstrap_user_data = true

      # Encrypted root volume with your KMS key
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_root_volume_size
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = var.ebs_kms_key_arn
            delete_on_termination = true
          }
        }
      }
      depends_on = ["vpc-cni"]
    }
  }

  # ==================================================================
  # Access – admin via IAM principal (your terraform-deployer user/role)
  # ==================================================================
  access_entries = {
    admin = {
      principal_arn = var.eks_admin_principal_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # ==================================================================
  # Logging & tagging
  # ==================================================================
  cloudwatch_log_group_retention_in_days = var.log_retention_days
  enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, {
    "GitHubRepo"  = var.github_repo
    "Environment" = var.environment
  })
}
