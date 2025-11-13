# Initial Bootstrap Setup (perform once per environment only)
Apply the Bootstrap Configuration
1. cd /bootstrap

2. Initialize and Apply the Bootstrap Configuration:
terraform init
terraform fmt
terraform validate
terraform apply

This creates the S3 bucket and DynamoDB table, with the state stored locally in bootstrap/terraform.tfstate

4. Create an IAM user in AWS 
In the AWS console create a new AWS user caled terraform-deployer and assign the AdministratorAccess and AmazonEKSClusterPolicy policies.
Generate Access Keys:

Go to the new user → Security credentials tab
Scroll to Access keys → Create access key
Choose: "Command Line Interface (CLI)"
Check: I understand the risks...
Click Next → Create access key

Add Secrets to GitHub
Go to your GitHub repo → Settings → Secrets and variables → Actions
Click New repository secret
Add 2 secrets:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

5. Verify Resources are created correctly.

6. Take note of backend config in Outputs. Update the backend files in /main to match.