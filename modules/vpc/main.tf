# ./modules/vpc/main.tf

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = [for i in range(3) : cidrsubnet(var.cidr, 8, i)]         # 10.0.0.0/24 – 10.0.2.0/24
  public_subnets  = [for i in range(3, 6) : cidrsubnet(var.cidr, 8, i + 10)] # 10.0.13.0/24 – 10.0.15.0/24

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

  # ##################################################
  # # Enable VPC Flow Logs (AVD-AWS-0***78 (MEDIUM))
  # ##################################################
  # enable_flow_log                      = true
  # flow_log_destination_type            = "cloud-watch-logs"
  # flow_log_destination_arn             = aws_cloudwatch_log_group.vpc_flow_logs.arn
  # flow_log_cloudwatch_log_group_kms_key_id = aws_kms_key.vpc_flow_logs_kms.arn
  # flow_log_max_aggregation_interval    = 60
}

# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/aws/vpc/flow-logs"
#   retention_in_days = 90

#   kms_key_id = aws_kms_key.vpc_flow_logs_kms.arn
# }
