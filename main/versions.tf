terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }

  backend "s3" {
    # Configured via -backend-config=<env>.backend.tfvars
    # Run bootstrap/ first to create the bucket and DynamoDB table
    skip_region_validation = true # ap-southeast-6 not yet in Terraform's region list
  }
}
