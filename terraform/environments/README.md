This folder contains per-environment Terraform configurations and variable files.

Usage

- Dev environment (workspace):

  cd environments/dev
  terraform init
  terraform plan -var-file=terraform.tfvars
  terraform apply -var-file=terraform.tfvars

- Prod environment (workspace):

  cd environments/prod
  terraform init
  terraform plan -var-file=terraform.tfvars
  terraform apply -var-file=terraform.tfvars

Notes

- Each environment contains its own `backend` configuration to store state separately (`dev` and `prod`).
- Customize `terraform.tfvars` in each environment to adjust sizes, counts, and names.
- The root `validate.sh` script checks for these files; run it from the `terraform/` directory.
