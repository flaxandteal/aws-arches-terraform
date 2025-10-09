# WIP!! This is untested currently and various things have yet to be completely ironed out.


# AWS Terraform Repository
Provisions a VPC, subnets, security group, Network ACL, internet gateway, route table, S3 VPC endpoint, IAM user, three S3 buckets (data, logs, Terraform state), an EKS cluster with CloudWatch logging, and a remote state backend in AWS, supporting dev, stage, uat, and prod environments.

# Prerequisites
Install Terraform (v1.5+).
Set AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY via environment variables or ~/.aws/credentials).

# Local Usage
1. Initialize:
```
terraform init
```


2. Create workspaces (required to avoid validation errors):terraform workspace new dev
```
terraform workspace new stage
terraform workspace new uat
terraform workspace new prod
```

3. Select a workspace:
```
terraform workspace select dev
```

4. Apply for an environment:
```
terraform apply -var-file=dev.tfvars
```

5. Validate configuration:
```
terraform validate
```

## sji todo - add bit about state bucket usage!

***Important Notes***
Always select a workspace (dev, stage, uat, prod) before running commands to avoid "Invalid value for variable" errors.
Use .tfvars files for environment-specific settings (e.g., dev.tfvars for cheaper regions).

# Well-Architected Framework

Security: Security group and least-privilege IAM.
Reliability: Multi-subnet in prod for multi-AZ. 
Cost Optimization: Smaller CIDRs in dev/stage.
Operational Excellence: Modular code, workspace-based naming.


# Repo Structure
aws-terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── dev.tfvars
├── stage.tfvars
├── uat.tfvars
├── prod.tfvars
├── terraform.tfvars.example
├── modules/
│   ├── common/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── access/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── eks/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── README.md
└── .gitignore


# Usage Local
cd aws
terraform init
terraform workspace new dev
terraform workspace select dev
terraform apply -var-file=dev.tfvars

Repeat for stage.tfvars, uat.tfvars, prod.tfvars.

terraform fmt --recursive
terraform validate

Scribbles
Terraform init —backend-config=/env/dev.conf

Terraform apply —var-file=/env/dev.tfvars