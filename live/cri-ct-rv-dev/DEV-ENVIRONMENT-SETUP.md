# Dev Environment Setup - Complete

## Overview

The dev environment (cri-ct-rv-dev) infrastructure has been fully mirrored from prod1 and is ready for customer provisioning.

## Account Information

- **Account ID**: 164804042272
- **Region**: us-east-1
- **Environment**: cri-ct-rv-dev

## Infrastructure Stacks

### 1. RDS Stack ✅ (Already Existed)
- **Location**: `live/cri-ct-rv-dev/rds/`
- **State Key**: `cri-ct-rv-dev/rds/terraform.tfstate`
- **Status**: Already deployed and operational

### 2. Compute Stack ✅ (Newly Created)
- **Location**: `live/cri-ct-rv-dev/compute/`
- **State Key**: `cri-ct-rv-dev/compute/terraform.tfstate`
- **Status**: Ready for initialization
- **Configuration File**: `terraform.auto.tfvars` (empty `dev_ec2_instances` map ready for customers)

**Key Features**:
- EC2 instance provisioning with Azure AD domain join
- DSC configuration for automated setup
- KMS encryption for EBS volumes
- Security groups for instance protection
- Outputs for ALB integration

### 3. ALB Stack ✅ (Newly Created)
- **Location**: `live/cri-ct-rv-dev/alb/`
- **State Key**: `cri-ct-rv-dev/alb/terraform.tfstate`
- **Status**: Ready for initialization
- **Configuration File**: `terraform.auto.tfvars` (empty `app_routes` map ready for customers)

**Key Features**:
- Application Load Balancer with SSL/TLS termination
- ACM certificate for `*.hosted.reflectsystems.com`
- S3 bucket for ALB access logs
- Security group for ALB protection
- HTTP to HTTPS redirect
- Dynamic routing based on host headers

## Configuration Differences from Prod1

### Variable Names
- **Prod1**: Uses `prod1_ec2_instances` variable
- **Dev**: Uses `dev_ec2_instances` variable

### Deletion Protection
- **Prod1**: Enabled (prevents accidental deletion)
- **Dev**: Disabled (allows easier cleanup and testing)

### ALB Name
- **Prod1**: `rv-prod1-shared-alb1`
- **Dev**: `rv-dev-shared-alb1`

### KMS Keys
- **Dev**: Uses Terraform-managed KMS key reference `aws_kms_key.this.arn`
- **Prod1**: Uses hardcoded KMS key ARN

## Provisioning UI Integration

The provisioning UI (running on EC2 instance i-040c9ba3f55a32497 in rv-shared account) is configured to generate correct Terraform configurations for the dev environment.

### Access
- **URL**: http://localhost:3000 (via SSM port forwarding)
- **Port Forwarding**: Running in background terminal ID 15
- **Profile**: rv-shared

### Configuration
The UI correctly generates:
- EC2 instance configuration with `aws_kms_key.this.arn` reference
- ALB routing configuration
- RDS instance configuration

## Next Steps

### 1. Initialize Terraform Stacks

```bash
# Initialize compute stack
cd live/cri-ct-rv-dev/compute
terraform init

# Initialize ALB stack
cd ../alb
terraform init
```

### 2. Deploy Base Infrastructure

```bash
# Deploy compute stack (creates base infrastructure)
cd live/cri-ct-rv-dev/compute
terraform plan
terraform apply

# Deploy ALB stack (creates load balancer)
cd ../alb
terraform plan
terraform apply
```

### 3. Test Customer Provisioning

1. Access the provisioning UI at http://localhost:3000
2. Fill out the customer provisioning form:
   - **Customer Name**: shem-test
   - **Environment**: cri-ct-rv-dev (Development)
   - **Instance Type**: t3.medium
   - **Subnet**: subnet-08476614697a4c96b
   - **Hostname**: shem-test.hosted.reflectsystems.com
3. Review the generated configuration
4. Copy the configurations to the respective `terraform.auto.tfvars` files:
   - Compute: `live/cri-ct-rv-dev/compute/terraform.auto.tfvars`
   - ALB: `live/cri-ct-rv-dev/alb/terraform.auto.tfvars`
   - RDS: `live/cri-ct-rv-dev/rds/terraform.auto.tfvars`
5. Run `terraform plan` and `terraform apply` in each stack

### 4. Verify Deployment

After applying the Terraform configurations:

1. **EC2 Instance**: Verify instance is running and domain-joined
2. **ALB**: Verify routing rule is created and health checks pass
3. **RDS**: Verify database is created and accessible
4. **DNS**: Verify hostname resolves to ALB
5. **Application**: Verify application is accessible via HTTPS

## File Structure

```
live/cri-ct-rv-dev/
├── compute/
│   ├── terraform.tf          # Backend configuration
│   ├── variables.tf           # Variable definitions
│   ├── main.tf                # EC2 instances, Azure AD join, DSC
│   ├── kms.tf                 # KMS key for EBS encryption
│   ├── sg.tf                  # Security groups
│   ├── outputs.tf             # Outputs for ALB integration
│   └── terraform.auto.tfvars  # Configuration (empty, ready for customers)
├── alb/
│   ├── terraform.tf           # Backend configuration
│   ├── variables.tf           # Variable definitions
│   ├── main.tf                # ALB resources and routing
│   ├── sg.tf                  # Security group for ALB
│   ├── acm.tf                 # ACM certificate
│   ├── s3.tf                  # S3 bucket for access logs
│   └── terraform.auto.tfvars  # Configuration (empty, ready for customers)
└── rds/
    ├── terraform.tf           # Backend configuration
    ├── variables.tf           # Variable definitions
    ├── main.tf                # RDS instances
    ├── kms.tf                 # KMS key for RDS encryption
    └── terraform.auto.tfvars  # Configuration (existing)
```

## Important Notes

1. **KMS Key Reference**: Dev environment uses `aws_kms_key.this.arn` which is a Terraform reference to the KMS key created in the compute stack. This is correct and will be resolved during `terraform plan`.

2. **Empty Maps**: Both `dev_ec2_instances` and `app_routes` maps are intentionally empty. They will be populated when customers are provisioned via the UI.

3. **Apply Order**: When provisioning a customer, apply in this order:
   - Compute (creates EC2 instance)
   - ALB (creates routing rule)
   - RDS (creates database, if needed)

4. **State Management**: All stacks use remote state in S3 bucket `cri-terraform-state-backend` with appropriate state keys.

## Troubleshooting

### Port Forwarding Not Working
```bash
# Check if port forwarding is running
aws ssm start-session --target i-040c9ba3f55a32497 \
  --document-name AWS-StartPortForwardingSession \
  --parameters "portNumber=3000,localPortNumber=3000" \
  --profile rv-shared --region us-east-1
```

### Terraform Init Fails
- Verify AWS credentials are configured for account 164804042272
- Verify S3 backend bucket exists and is accessible
- Verify IAM role `terraform-execute` exists in the account

### KMS Key Issues
- The `aws_kms_key.this.arn` reference is correct for dev environment
- It will be resolved during `terraform plan` from the compute stack's KMS resource
- Do not replace with a hardcoded ARN

## Status

✅ **Complete**: Dev environment infrastructure is fully configured and ready for customer provisioning.

**Next Action**: Initialize and deploy the base infrastructure, then test customer provisioning via the UI.
