# AWS Terraform Repository
Provisions a VPC, subnets, security group, Network ACL, internet gateway, route table, S3 VPC endpoint, IAM user, three S3 buckets (data, logs, Terraform state), an EKS cluster with CloudWatch logging, and a remote state backend in AWS, supporting dev, stage, uat, and prod environments.

# Prerequisites
1. Install Terraform (v1.5+).
***Do yourself a favour and use tfenv to manage versions***
```
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
source ~/.bashrc  # or ~/.zshrc
tfenv list-remote
terraform <version>  or tfenv install latest
```

2. Set AWS credentials.
```
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="eu-north-1"
```
Ensure the AWS credentials used for bootstrap.tf have permissions to create S3 buckets and DynamoDB tables.

Test your AWS credentials using the AWS CLI:
```
aws sts get-caller-identity
```
This should return your AWS account details. If it fails, your credentials are invalid or misconfigured.

# Initial Bootstrap Setup (perform once per environment only)
See bootstrap/README.md

# Create/Update AWS Infrastructure
See main/README.md

# Well-Architected Framework
Security: Security group and least-privilege IAM.
Reliability: Multi-subnet in prod for multi-AZ. 
Cost Optimization: Smaller CIDRs in dev/stage.
Operational Excellence: Modular code, workspace-based naming.


Component,Key Requirements
Single VPC,With private subnets only (no public subnets in F&T scope)
Private subnets,Separate subnets for UAT and Production (can be in same AZs but tagged differently)
Database subnet group,Separate private subnets for RDS (isolated from app subnets)
EKS Cluster (UAT),"Fully private, private endpoint only, separate cluster"
EKS Cluster (Production),"Fully private, private endpoint only, separate cluster"
RDS PostgreSQL,"Multi-AZ, private, encrypted, in dedicated DB subnets"
S3 buckets,"Versioning, KMS encryption, private only (via VPC endpoints)"
VPC Endpoints (Gateway & Interface),"S3, ECR DKR, ECR API, SSM, SSMMessages, EC2Messages, STS, KMS, Logs, etc."
KMS CMKs,"One per environment (or shared with strict policy), rotation enabled"
IAM roles & policies,"OIDC for GitHub Actions, IRSA roles, scoped by tags/environment"
Security Groups,"Restrictive rules (EKS → RDS, pods → S3/RDS, etc.)"
Terraform backend,S3 + DynamoDB + KMS encryption

# Repo Structure
```
aws-arches-terraform/
├── bootstrap/
│   ├── bootstrap.tf  # Defines S3 bucket and DynamoDB table to hold Terraform State
│   └── terraform.tfstate  # Local state for bootstrap
├── .terraform-version
├── main.tf
├── variables.tf
├── dev.tfvars
├── staging.tfvars
├── uat.tfvars
├── prod.tfvars
├── modules/
│   ├── common/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── kms/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
```

SJI TODO!!!!
Migrate to OIDC (recommended for DOC compliance – removes AWS keys entirely)
replace the env block with:
YAML- name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActions-Terraform-${{ inputs.environment }}
          aws-region: ap-southeast-2
…and delete AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY secrets.

## AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
aws configure
This prompts you to enter:

    AWS Access Key ID
    AWS Secret Access Key
    Default region (e.g., eu-north-1)
    Output format (e.g., json) This creates a ~/.aws/credentials file and a ~/.aws/config file.

aws sts get-caller-identity

## Set Environment variables
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="eu-north-1"
Add these to your ~/.bashrc, ~/.zshrc, or equivalent to persist them across sessions.