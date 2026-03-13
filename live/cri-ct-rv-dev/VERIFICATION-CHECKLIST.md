# Dev Environment - File Verification Checklist

## ✅ All Files Ready for Deployment

### Compute Stack (`live/cri-ct-rv-dev/compute/`)

| File | Status | Notes |
|------|--------|-------|
| `terraform.tf` | ✅ | Backend: `cri-ct-rv-dev/compute/terraform.tfstate` |
| `variables.tf` | ✅ | Uses `dev_ec2_instances` variable (correct for dev) |
| `main.tf` | ✅ | EC2 instances, Azure AD join, DSC configuration |
| `kms.tf` | ✅ | KMS key for EBS encryption |
| `sg.tf` | ✅ | Security groups for EC2 instances |
| `outputs.tf` | ✅ | Outputs `dev_ec2_instances` map for ALB integration |
| `terraform.auto.tfvars` | ✅ | Empty `dev_ec2_instances = {}` ready for customers |

### ALB Stack (`live/cri-ct-rv-dev/alb/`)

| File | Status | Notes |
|------|--------|-------|
| `terraform.tf` | ✅ | Backend: `cri-ct-rv-dev/alb/terraform.tfstate` |
| `variables.tf` | ✅ | Uses `app_routes` variable with validation |
| `main.tf` | ✅ | ALB with routing, reads compute remote state |
| `sg.tf` | ✅ | Security group for ALB |
| `acm.tf` | ✅ | ACM certificate for `*.hosted.reflectsystems.com` |
| `s3.tf` | ✅ | S3 bucket for ALB access logs |
| `terraform.auto.tfvars` | ✅ | Empty `app_routes = {}` ready for customers |

### RDS Stack (`live/cri-ct-rv-dev/rds/`)

| File | Status | Notes |
|------|--------|-------|
| All files | ✅ | Already existed, no changes needed |

## Key Configuration Verification

### ✅ Account Numbers
- **Compute**: `164804042272` (correct for dev)
- **ALB**: `164804042272` (correct for dev)

### ✅ Backend State Keys
- **Compute**: `cri-ct-rv-dev/compute/terraform.tfstate`
- **ALB**: `cri-ct-rv-dev/alb/terraform.tfstate`

### ✅ Variable Names
- **Compute**: Uses `dev_ec2_instances` (not `prod1_ec2_instances`)
- **ALB**: Uses `app_routes` (same as prod1)

### ✅ VPC/Subnet Names
- **VPC**: `rv-dev-vpc`
- **Subnets**: `dev-private-1`, `dev-private-2`, `dev-private-3`, etc.

### ✅ ALB Configuration
- **Name**: `rv-dev-shared-alb1`
- **Deletion Protection**: `false` (correct for dev)
- **Certificate**: `*.hosted.reflectsystems.com`

### ✅ Remote State Reference
- ALB stack correctly reads from compute stack's remote state
- State key: `cri-ct-rv-dev/compute/terraform.tfstate`
- Output reference: `dev_ec2_instances` (matches compute output)

### ✅ KMS Key Configuration
- Provisioning UI uses `aws_kms_key.this.arn` for dev (Terraform reference)
- This is correct and will be resolved during terraform plan

## Differences from Prod1 (Intentional)

| Aspect | Prod1 | Dev | Reason |
|--------|-------|-----|--------|
| Variable name | `prod1_ec2_instances` | `dev_ec2_instances` | Environment-specific naming |
| Deletion protection | `true` | `false` | Allow easier cleanup in dev |
| ALB name | `rv-prod1-shared-alb1` | `rv-dev-shared-alb1` | Environment identification |
| VPC name | `rv-prod1-vpc` | `rv-dev-vpc` | Environment identification |
| Subnet names | `prod1-*` | `dev-*` | Environment identification |

## Ready for Next Steps

The infrastructure is **100% ready** for:

1. ✅ `terraform init` in both compute and ALB stacks
2. ✅ `terraform plan` to preview infrastructure
3. ✅ `terraform apply` to deploy base infrastructure
4. ✅ Customer provisioning via UI at http://localhost:3000

## No Issues Found

All files are correctly configured and ready for deployment when you're ready.
