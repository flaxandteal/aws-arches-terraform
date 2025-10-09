resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/${var.name}-eks-logs-${terraform.workspace}"
  retention_in_days = var.clusters.log_retention_days
  tags              = merge(var.tags, var.extra_tags, { Name = "${var.name}-eks-logs-${terraform.workspace}" })
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.name}-eks-cluster-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-eks-cluster-role-${terraform.workspace}" })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy" "eks_cloudwatch_logs" {
  name = "${var.name}-eks-cloudwatch-logs-${terraform.workspace}"
  role = aws_iam_role.eks_cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.eks_logs.arn}:*"
      }
    ]
  })
}

resource "aws_eks_cluster" "main" {
  name     = "${var.name}-eks-${terraform.workspace}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = terraform.workspace == "prod" ? false : true
  }

  enabled_cluster_log_types = ["audit", "authenticator"]

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-eks-${terraform.workspace}" })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy.eks_cloudwatch_logs,
    aws_cloudwatch_log_group.eks_logs
  ]
}

resource "aws_iam_role" "eks_node_group" {
  name = "${var.name}-eks-node-group-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-eks-node-group-role-${terraform.workspace}" })
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "eks_autoscaler" {
  count = terraform.workspace == "prod" ? 1 : 0
  name  = "${var.name}-eks-autoscaler-${terraform.workspace}"
  role  = aws_iam_role.eks_node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name}-node-group-${terraform.workspace}"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.clusters.desired_size
    max_size     = var.clusters.max_size
    min_size     = var.clusters.min_size
  }

  instance_types = [var.clusters.instance_type]

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-node-group-${terraform.workspace}" })

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly,
    aws_iam_role_policy.eks_autoscaler
  ]
}

resource "helm_release" "cluster_autoscaler" {
  count      = terraform.workspace == "prod" ? 1 : 0
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  depends_on = [aws_eks_node_group.main]
}