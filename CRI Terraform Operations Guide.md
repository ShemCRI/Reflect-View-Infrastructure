1. Purpose and scope
This guide shows CRI engineers how to use Terraform to deploy and manage application resources in AWS:
• EC2 instances (Compute stack)
• RDS instances (RDS stack)
• ALB listener rules and target groups (ALB stack)
Networking resources (VPC, subnets, Transit Gateway, routing, Direct Connect, DNS resolver architecture) are owned by RapidScale. Do not change networking via Terraform. For networking changes, open a request with RapidScale.
2. Terraform design overview
The environment is organized into three independent Terraform stacks. Each stack manages a distinct layer of the application infrastructure. All stacks use open-source modules from the public Terraform Registry and are driven entirely through terraform.auto.tfvars files. Day-to-day operations do not require changes to .tf code.
2.1 Stack layout
repo-root/
  compute/
    main.tf
    terraform.auto.tfvars      # Edit for EC2 changes
  alb/
    main.tf
    terraform.auto.tfvars      # Edit for ALB route changes
  rds/
    main.tf
    terraform.auto.tfvars      # Edit for RDS changes
2.2 How the stacks connect
• Compute -> ALB: the Compute stack outputs a map of EC2 instance IDs (prod1_ec2_instances). The ALB stack reads this map via terraform_remote_state pointing to the Compute state file in S3 (cri-ct-rv-prod1/compute/terraform.tfstate). This is how ALB knows which EC2 instance to register as a target for each route.
• RDS: the RDS stack is fully independent. It has no cross-stack dependencies and can be applied at any time.
• Networking discovery: stacks discover required VPC/subnet metadata at plan/apply time using AWS data sources and resource tags. Where a subnet must be selected for placement, CRI must use only RapidScale-approved private subnets.
3. Tfvars-driven workflow (the only file you edit)
Each stack follows the same pattern for provisioning resources:
• Each stack defines a map(object(...)) variable (prod1_ec2_instances, rds_instances, app_routes).
• The variable defaults to an empty map {}, so no resources are created until you add an entry.
• Terraform uses for_each on this map. Adding a key provisions a complete set of resources for that entry (EC2 + SG + IAM, or an RDS instance, or a target group + listener rule).
• Removing a key destroys only that entry's resources. Other entries are unaffected.
4. Prerequisites on your workstation (Mac)
• Terraform installed (version should match the repository's required_version).
• AWS CLI v2 installed.
• Git access to the CRI Terraform repository.
• Access to assume the Shared Services role used for Terraform state (see Section 5).
Recommended: do Terraform runs from a dedicated working directory per stack, and do not run concurrent applies from multiple laptops.
5. AWS CLI access and role assumption for Terraform state
Terraform state for these stacks is stored in the Shared Services AWS account:
• Account: 530258393729 (CRI-Shared-Services)
• Existing automation role: arn:aws:iam::530258393729:role/terraform-execute
To run Terraform from your laptop, your AWS credentials must be able to read and write the state files in that account (S3) and acquire the state lock (DynamoDB) if locking is enabled. 

5.1 Dedicated CRI human-operator role
As per best practice we’ve creates a dedicated role for CRI engineers instead of reusing the terraform-execute automation role. This keeps permissions and audit trails clean and reduces blast radius.
•	CRI engineers authenticate using AWS SSO (Identity Center) into account 530258393729 (AdministratorAccess permission set).
•	They then assume the Shared Services Terraform runner role: arn:aws:iam::530258393729:role/terraform-execute-cri.
•	Terraform backend is stored in S3 bucket cri-terraform-state-backend in Shared Services.
•	Terraform provider assumes arn:aws:iam::<targetAccount>:role/terraform-execute to create resources in target accounts (example: 786284303891).

5.2  configure an AWS CLI profile (SSO Based)

CRI engineers already use AWS SSO for CLI access. Use your existing SSO workflow/profile and run Terraform under the Shared Services runner role. 

Runner Role - arn:aws:iam::530258393729:role/terraform-execute-cri

At minimum, confirm you have an SSO profile for account 530258393729, then assume the runner role in Shared Services (530258393729) as needed. 

Then run for validation:

aws sts get-caller-identity

5.4 Validate you can reach the Terraform backend
Run these checks before terraform init:
aws sts get-caller-identity
aws s3 ls s3://cri-terraform-state-backend/cri-ct-rv-prod1/compute/
6. Day-to-day Terraform commands
Run Terraform per-stack from that stack directory. Typical workflow:
cd compute/
terraform init
terraform plan
terraform apply
Repeat for alb/ and rds/ as needed. Use terraform plan before apply, and review the diff carefully.
7. Adding a new EC2 instance (Compute stack)
File to edit: compute/terraform.auto.tfvars
Variable: prod1_ec2_instances
Step 1 - Add an entry to the map. All required fields must be provided:
prod1_ec2_instances = {
  app1 = {
    ami_id               = "ami-0159172a5a821bafd"   # Windows Server 2022
    instance_type        = "t3.medium"
    subnet_id            = "subnet-0abc123def456789a" # change as needed so not all instances are in the sams subnet
    root_ebs_size        = 80 
    root_ebs_type        = "gp3"
    root_ebs_kms_key_arn = "arn:aws:kms:us-east-1:109743757398:key/"
    deletion_protection  = true
    user_data = <<-EOF
      <powershell>
      $desiredName = "app1-server"
      if ($env:COMPUTERNAME -ne $desiredName) {
        Rename-Computer -NewName $desiredName -Force -Restart
      }
      </powershell>
    EOF
    tags = {}
  }
}
Step 2 - Apply:
cd compute/
terraform plan
terraform apply
8. Adding a new RDS instance (RDS stack)
File to edit: rds/terraform.auto.tfvars
Variable: rds_instances
Step 1 - Add an entry to the map. Only required fields are shown below; others have sensible defaults.
rds_instances = {
  client01 = {
    identifier                    = "rv-prod01-shared-rds01"
    instance_class                = "db.t3.2xlarge"
    kms_key_id                    = "arn:aws:kms:us-east-1:109743757398:key/
    allocated_storage             = 100
    max_allocated_storage         = 500
    manage_master_user_password   = true
    master_user_secret_kms_key_id = "arn:aws:kms:us-east-1:109743757398:key/"
    monitoring_role_name          = "sqlserver-rds-client01-monitoring-role"
    backup_retention_period       = 30
  }
  client02 = {
    identifier            = "rv-prod01-shared-rds02"
    instance_class        = "db.m6i.large"
    kms_key_id            = "arn:aws:kms:us-east-1:109743757398:key/"
    allocated_storage     = 200
    max_allocated_storage = 1000
    monitoring_role_name  = "sqlserver-rds-client02-monitoring-role"
  }
}
Step 2 - Apply:
cd rds/
terraform plan
terraform apply
9. Adding a new ALB route (ALB stack)

File to edit: alb/terraform.auto.tfvars
Variable: app_routes
Prerequisite: the EC2 instance this route points to must already exist in the Compute stack outputs. Apply Compute first if the instance is new.
Step 1 - Add an entry to the map. All fields are required:
app_routes = {
  app1 = {
    instance_key   = "app1"
    host_headers   = ["app1.hosted.reflectsystems.com"]
    priority       = 200
    backend_port   = 443
    backend_proto  = "HTTPS"
    health_path    = "/health"
    health_matcher = "200"
  }
  app2 = {
    instance_key   = "app2"
    host_headers   = ["app2.hosted.reflectsystems.com"]
    priority       = 300
    backend_port   = 8080
    backend_proto  = "HTTP"
    health_path    = "/"
    health_matcher = "200-399"
  }
}
Step 2 - Apply:
cd alb/
terraform plan
terraform apply
10. Apply order and dependencies





Recommended apply order:


Step	Command	Notes
1 (Compute)	cd compute  terraform plan / apply	Apply first when adding new EC2 instances. Writes instance IDs to state.
2 (ALB)	cd alb  terraform plan /apply	Apply after Compute so terraform_remote_state resolves new instance IDs.
Any (RDS)	cd rds/  terraform plan  apply	Independent. Can be applied at any time.
11. Key considerations and gotchas
11.1 RDS
• Identifiers cannot end with a hyphen. Example: rv-prod01-rds- is invalid.
• Each RDS instance requires a unique monitoring_role_name to avoid IAM role name collisions.
• When manage_master_user_password = true, the master password is stored in AWS Secrets Manager (no plaintext in Terraform).
• If create_db_option_group = false, the referenced option group must already exist.
11.2 EC2
• user_data must be plain text in tfvars. Terraform functions (for example base64encode()) cannot be used in .tfvars files. The module code handles encoding.
• Security groups are created automatically with a baseline rule set. Custom SG rules require a code change.
• Azure AD join and DSC registration are applied via SSM association targeting tags (azure-ad-join and azure-dsc).
11.3 ALB
• Route priorities must be unique across app_routes. Priorities must be between 1 and 50000.
• Priority 100 is reserved for the existing yme route (hardcoded in Terraform).
• backend_proto must be HTTP or HTTPS (case-sensitive per validation).
• instance_key must exactly match a key in prod1_ec2_instances. Mismatch causes a plan-time failure.
12. Troubleshooting quick checks
• Confirm identity: aws sts get-caller-identity
• Confirm backend access: aws s3://cri-terraform-state-backend/cri-ct-rv-prod1/compute/• 
If state lock issues occur, confirm DynamoDB lock table permissions and check for stale locks.
• If Terraform cannot find VPC/subnet, confirm required Name tags exist and match the expected filters.
