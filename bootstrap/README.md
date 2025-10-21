# Initial Bootstrap Setup (perform once per environment only)
Apply the Bootstrap Configuration
1. cd /bootstrap

2. Create an IAM user in AWS 
In the AWS console create a new AWS user with the permissions in the json policies file in /aws-terraform-user-policies.

3. Initialize and Apply the Bootstrap Configuration:
terraform init
terraform fmt
terraform validate
terraform apply

This creates the S3 bucket and DynamoDB table, with the state stored locally in bootstrap/terraform.tfstate

4. Verify Resources:
Check that the S3 bucket and DynamoDB table were created:
aws s3 ls s3://my-terraform-state-bucket-123
aws dynamodb describe-table --table-name terraform-locks --region eu-central-1