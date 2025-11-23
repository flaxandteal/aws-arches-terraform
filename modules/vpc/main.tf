# modules/vpc/main.tf

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = [for i in range(3) : cidrsubnet(var.cidr, 8, i)]
  public_subnets  = [for i in range(3, 6) : cidrsubnet(var.cidr, 8, i + 10)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = merge(
    {
      "Name"                              = var.name
      "kubernetes.io/cluster/${var.name}" = "shared"
      "Environment"                       = var.name
    },
    var.tags
  )

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  enable_dns_hostnames = true # ← private hosted zone
  enable_dns_support   = true # ← Route 53 resolution

  # ##################################################
  # # Enable VPC Flow Logs (AVD-AWS-0***78 (MEDIUM))
  # ##################################################
  enable_flow_log           = true
  flow_log_destination_type = "s3"
  flow_log_destination_arn  = module.s3_logging_bucket.bucket_arn
  vpc_flow_log_tags         = var.tags

  create_flow_log_cloudwatch_log_group = false # prevents creation of CW log group
  create_flow_log_cloudwatch_iam_role  = true  # auto-creates the required role
  flow_log_max_aggregation_interval    = 60
  flow_log_traffic_type                = "ALL" # or "REJECT" to save ~60 % cost

  flow_log_cloudwatch_log_group_retention_in_days = 365 #sji move this and some of above to tfvars
}