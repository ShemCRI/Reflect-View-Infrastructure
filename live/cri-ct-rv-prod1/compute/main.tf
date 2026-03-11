provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_number}:role/terraform-execute"
  }

  default_tags {
    tags = {
      "map-migrated" = "mig7NUU2YAD76"
    }
  }
}

locals {
  app_ec2_baseline_managed_policies = {
    cloudwatch_agent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ssm_core         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

module "db_migrator" {
  source              = "code.logicworks.net/terraform-modules/terraform-aws-ec2-instance/aws"
  version             = "2.3.0"
  ami_id              = "ami-0159172a5a821bafd" #Microsoft Windows Server 2022
  base_instance_tag   = "prod1-db-migrator"
  deletion_protection = false
  keypair_name        = var.keypair_name
  security_group_ids  = [aws_security_group.sg_ec2_db_migrator.id]
  subnet_id           = local.networking.private_subnet_ids[1]
  root_ebs_size       = "30"
  root_ebs_type       = var.root_ebs_type
  root_ebs_kms_key    = module.ebs_key.key_arn
  instance_type       = "t3a.xlarge"
  attach_lw_policies  = true
  policies            = ["arn:aws:iam::${var.account_number}:policy/db-migration-s3-access"]
  user_data = base64encode(<<-EOF
  <powershell>
  $desiredName = "prod1-db-migrator"
  if ($env:COMPUTERNAME -ne $desiredName) {
    Rename-Computer -NewName $desiredName -Force -Restart
  }
  </powershell>
EOF
  )
  tags = {
    "azure-ad-join" = "true"
    "azure-dsc"     = "true"
  }

  depends_on = [aws_iam_policy.db_migrator_s3_access]
}

module "keypair" {
  source   = "code.logicworks.net/terraform-modules/terraform-aws-ec2-key-pair/aws"
  version  = "1.2.1"
  key_name = "cri-ct-rv-prod1-kp"
}

module "ebs_key" {
  source  = "code.logicworks.net/terraform-modules/terraform-aws-kms/aws"
  version = "0.9.0"
  alias   = "${var.environment}-ebs"
}

module "azure_ad_domain_join" {
  source = "../../../modules/azure-ad-domain-join"

  environment             = var.environment
  domain_name             = var.azure_ad_domain_name
  dns_ips                 = var.azure_ad_dns_ips
  ou_path                 = var.azure_ad_ou_path
  username_parameter_name = var.domain_join_username_parameter
  password_parameter_name = var.domain_join_password_parameter

  # Target any instance with azure-ad-join = "true" tag
  target_tag_key   = "azure-ad-join"
  target_tag_value = "true"
}

module "azure_dsc_registration" {
  source = "../../../modules/azure-dsc-registration"

  environment                = var.environment
  registration_url_parameter = var.dsc_registration_url_parameter
  registration_key_parameter = var.dsc_registration_key_parameter
  node_configuration_name    = var.dsc_node_configuration_name

  # Target any instance with azure-dsc = "true" tag
  target_tag_key   = "azure-dsc"
  target_tag_value = "true"
}

#######################################
# IAM Policy for DB Migrator S3 Access
#######################################
data "aws_iam_policy_document" "db_migrator_s3_access" {
  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::cri-rv-db-migrations"
    ]
  }

  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:PutObjectAcl",
      "s3:GetObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::cri-rv-db-migrations/*"
    ]
  }
}

resource "aws_iam_policy" "db_migrator_s3_access" {
  name        = "db-migration-s3-access"
  description = "Policy for DB migrator EC2 to access the shared DB migrations S3 bucket"
  policy      = data.aws_iam_policy_document.db_migrator_s3_access.json
}

#######################################
# EC2 Instance: aws-rv3-yme
#######################################
module "aws_rv3_yme" {
  source              = "code.logicworks.net/terraform-modules/terraform-aws-ec2-instance/aws"
  version             = "2.3.0"
  ami_id              = "ami-0159172a5a821bafd" #Microsoft Windows Server 2022
  base_instance_tag   = "aws-rv3-yme"
  deletion_protection = true
  keypair_name        = var.keypair_name
  security_group_ids  = [aws_security_group.sg_ec2_yme.id]
  subnet_id           = local.networking.private_subnet_ids[0]
  root_ebs_size       = "80"
  root_ebs_type       = var.root_ebs_type
  root_ebs_kms_key    = module.ebs_key.key_arn
  instance_type       = "t3.medium"
  attach_lw_policies  = true

  user_data = base64encode(<<-EOF
  <powershell>
  $desiredName = "aws-rv3-yme"
  if ($env:COMPUTERNAME -ne $desiredName) {
    Rename-Computer -NewName $desiredName -Force -Restart
  }
  </powershell>
EOF
  )

  tags = {
    "Name"          = "cri-ct-rv-prod1"
    "azure-ad-join" = "true"
    "azure-dsc"     = "true"
  }
}

#######################################
# Open Source Pattern for New Instances
#######################################
module "app_ec2_instances" {
  for_each = var.prod1_ec2_instances

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name                    = each.key
  ami                     = each.value.ami_id
  instance_type           = each.value.instance_type
  subnet_id               = each.value.subnet_id
  key_name                = var.keypair_name
  monitoring              = true
  disable_api_termination = each.value.deletion_protection
  vpc_security_group_ids  = [aws_security_group.app_ec2[each.key].id]

  root_block_device = [{
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = each.value.root_ebs_kms_key_arn
    size                  = each.value.root_ebs_size
    type                  = each.value.root_ebs_type
  }]
  volume_tags = {
    Name = "${each.key} - /dev/sda1"
  }

  create_iam_instance_profile = true
  iam_role_name               = "${each.key}-ec2-role"
  iam_role_use_name_prefix    = false
  iam_role_description        = "Baseline IAM role for ${each.key}"
  iam_role_policies           = local.app_ec2_baseline_managed_policies

  # Keep tfvars simple: users provide plain user_data, we encode here.
  user_data_base64 = base64encode(each.value.user_data)

  tags = merge(
    each.value.tags,
    {
      "azure-ad-join" = "true"
      "azure-dsc"     = "true"
      "Name"          = "rv-${var.environment}-${each.key}"
    }
  )
}