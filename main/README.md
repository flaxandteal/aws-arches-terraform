# Create/Update AWS Infrastructure
1. cd /main

1. Initialize:
```
terraform init
```

2. Format and Validate Terraform
terraform fmt --recursive
terraform validate
```

Run this once from inside modules/secrets/rotation/: 
pip install psycopg2-binary -t python
zip -r ../rotation.zip python lambda_function.py
This ensures all dependencies are included.

The resulting rotation.zip goes in modules/secrets/.


***Important Notes***
Use .tfvars files for environment-specific settings (e.g., dev.tfvars for cheaper regions).

If rerunning this secrets may be a problem. You may get this error:
Error: creating Secrets Manager Secret (catalina/rds-credentials): operation error Secrets Manager: CreateSecret, https response error StatusCode: 400, RequestID: 5eef5c99-dd26-41bb-866e-b02004b45660, InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.

To delete the secret:
aws secretsmanager list-secrets --query 'SecretList[].Name' --region'<your-region>'
# find catalina/rds-credentials

aws secretsmanager delete-secret \
  --secret-id catalina/rds-credentials \
  --force-delete-without-recovery \
  --region'<your-region>'

