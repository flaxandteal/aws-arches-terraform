# common module is stateless (no resources) hence this file is minimal

locals {
  tags = merge(var.common_tags, {
    Environment = var.environment
  })

  cidr_blocks = {
    dev   = "10.0.0.0/24"
    stage = "10.0.0.0/22"
    uat   = "10.0.0.0/20"
    prod  = "10.0.0.0/16"
  }
}
