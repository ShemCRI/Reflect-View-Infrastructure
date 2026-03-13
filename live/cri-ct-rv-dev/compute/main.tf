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

module "keypair" {
  source   = "code.logicworks.net/terraform-modules/terraform-aws-ec2-key-pair/aws"
  version  = "1.2.1"
  key_name = "cri-ct-rv-dev-kp"
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
# Open Source Pattern for New Instances
#######################################
module "app_ec2_instances" {
  for_each = var.dev_ec2_instances

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
