# modules/eks/main.tf

# Fully private EKS cluster

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # ==================================================================
  # FULLY PRIVATE – no public access allowed
  # ==================================================================
  endpoint_private_access = true
  endpoint_public_access  = false

  # Optional: dedicated subnets for control plane (more isolation)
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # ==================================================================
  # Access – admin via IAM principal (terraform-deployer)
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
  # Addons
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
  # Node Group
  # ==================================================================
  eks_managed_node_groups = {
    main = {
      name           = "main"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      ami_type                   = var.node_ami_type # AL2023_ARM_64_STANDARD
      enable_bootstrap_user_data = true

      # Encrypted root volume with KMS key
      ebs_encrypted  = true
      ebs_kms_key_id = null
    }
  }

  # ==================================================================
  # LOCK DOWN NODE EGRESS – remove 0.0.0.0/0 internet access
  # ==================================================================
  # node_security_group_additional_rules = {
  #   # Allow nodes to pull images from ECR + talk to EKS API (in-VPC)
  #   egress_vpc = {
  #     description = "Node to VPC (for EKS API, DNS, ECR dkr endpoints)"
  #     protocol    = "-1"
  #     from_port   = 0
  #     to_port     = 0
  #     type        = "egress"
  #     cidr_blocks = [var.vpc_cidr]  # e.g. "10.0.0.0/16"
  #   }

  #   # Optional: allow HTTPS only to AWS services (if you need S3, DynamoDB, etc.)
  #   egress_https_443 = {
  #     description = "Node HTTPS to AWS services"
  #     protocol    = "tcp"
  #     from_port   = 443
  #     to_port     = 443
  #     type        = "egress"
  #     cidr_blocks = ["0.0.0.0/0"]
  #     # Safe because it's only port 443
  #   }

  #   # Optional: allow DNS (UDP 53)
  #   egress_dns = {
  #     description = "Node DNS resolution"
  #     protocol    = "udp"
  #     from_port   = 53
  #     to_port     = 53
  #     type        = "egress"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }
  # }

  # # COMPLETELY DISABLE the default permissive rules created by the module
  # create_node_security_group = true
  # node_security_group_tags = {
  #   "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  # }

  # ==================================================================
  # Logging & tagging
  # ==================================================================
  cloudwatch_log_group_retention_in_days = var.log_retention_days
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, {
    Name                                              = local.cluster_name
    GitHubRepo                                        = var.github_repo
    Environment                                       = var.environment
    "k8s.io/cluster-autoscaler/enabled"               = "true"
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
  })
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
