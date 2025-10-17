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

***Important Notes***
Use .tfvars files for environment-specific settings (e.g., dev.tfvars for cheaper regions).