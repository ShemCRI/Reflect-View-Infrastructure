# Quick Start: Customer Provisioning

## Access the Provisioning UI

1. **Start Port Forwarding** (if not already running):
   ```bash
   aws ssm start-session --target i-040c9ba3f55a32497 \
     --document-name AWS-StartPortForwardingSession \
     --parameters "portNumber=3000,localPortNumber=3000" \
     --profile rv-shared --region us-east-1
   ```

2. **Open Browser**: Navigate to http://localhost:3000

## Provision a Customer

### Step 1: Fill Out Form
- Customer Name: `customer-name` (lowercase, hyphens only)
- Environment: Select from dropdown (Dev, Prod1, etc.)
- Instance Type: `t3.medium` (or as needed)
- Subnet: Select from dropdown
- Hostname: `customer-name.hosted.reflectsystems.com`

### Step 2: Review Configuration
The UI generates three configuration blocks:
- EC2 Configuration (Compute Stack)
- ALB Configuration (ALB Stack)
- RDS Configuration (RDS Stack)

### Step 3: Apply Configuration

```bash
# 1. Add EC2 config to compute stack
cd live/cri-ct-rv-{env}/compute
# Edit terraform.auto.tfvars, add to dev_ec2_instances or prod1_ec2_instances map
terraform plan
terraform apply

# 2. Add ALB config to ALB stack
cd ../alb
# Edit terraform.auto.tfvars, add to app_routes map
terraform plan
terraform apply

# 3. Add RDS config to RDS stack (if needed)
cd ../rds
# Edit terraform.auto.tfvars, add to rds_instances map
terraform plan
terraform apply
```

## Dev Environment Status

✅ **Ready**: All infrastructure stacks are configured and ready
- Compute stack: `live/cri-ct-rv-dev/compute/`
- ALB stack: `live/cri-ct-rv-dev/alb/`
- RDS stack: `live/cri-ct-rv-dev/rds/`

## Next Steps

1. Initialize Terraform in compute and ALB stacks (`terraform init`)
2. Deploy base infrastructure (`terraform apply`)
3. Test customer provisioning via UI
4. Verify deployment and access

See `live/cri-ct-rv-dev/DEV-ENVIRONMENT-SETUP.md` for detailed information.
