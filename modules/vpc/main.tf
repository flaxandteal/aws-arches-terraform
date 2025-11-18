locals {
  tags = {}
}

# --------------------------------------------------------------
# VPC + Subnets
# --------------------------------------------------------------
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"


  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = [for i in range(3) : cidrsubnet(var.cidr, 8, i)]
  public_subnets  = [for i in range(3, 6) : cidrsubnet(var.cidr, 8, i + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = merge(
    var.common_tags,
    local.tags,
    { "kubernetes.io/cluster/${var.name}" = "shared" }
  )

  # Tag subnets for load balancers
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}