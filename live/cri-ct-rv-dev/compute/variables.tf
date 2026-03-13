variable "account_number" {
  description = "target account no"
}
variable "region" {
  description = "target region"
}
variable "keypair_name" {
  type = string
}
variable "root_ebs_type" {
  description = "root ebs type"
  type        = string
}
variable "environment" {
  description = "environment name"
  type        = string
}

variable "azure_ad_domain_name" {
  description = "Azure AD DS DNS domain name"
  type        = string
}

variable "azure_ad_dns_ips" {
  description = "List of Azure AD DS DNS IP addresses"
  type        = list(string)
}

variable "azure_ad_ou_path" {
  description = "Target OU distinguished name for domain join"
  type        = string
}

variable "domain_join_username_parameter" {
  description = "Name of SSM parameter (String) that stores the domain join username"
  type        = string
}

variable "domain_join_password_parameter" {
  description = "Name of SSM parameter (SecureString) that stores the domain join password"
  type        = string
}

# Azure Automation DSC variables
variable "dsc_registration_url_parameter" {
  description = "Name of SSM parameter (String) that stores the Azure Automation DSC registration URL"
  type        = string
}

variable "dsc_registration_key_parameter" {
  description = "Name of SSM parameter (SecureString) that stores the Azure Automation DSC registration key"
  type        = string
}

variable "dsc_node_configuration_name" {
  description = "Name of the DSC node configuration to apply (e.g., MyConfig.localhost)"
  type        = string
}

variable "dev_ec2_instances" {
  description = "Map of new OSS-backed EC2 instances to create. Keys are instance identifiers used for names/outputs."
  type = map(object({
    ami_id               = string
    instance_type        = string
    subnet_id            = string
    root_ebs_size        = number
    root_ebs_type        = string
    root_ebs_kms_key_arn = string
    deletion_protection  = bool
    user_data            = string
    tags                 = map(string)
  }))
  default = {}
}

locals {
  networking = {
    vpc_id             = data.aws_vpc.vpc.id
    db_subnet_ids      = [data.aws_subnet.db1.id, data.aws_subnet.db2.id, data.aws_subnet.db3.id]
    private_subnet_ids = [data.aws_subnet.private1.id, data.aws_subnet.private2.id, data.aws_subnet.private3.id]
    public_subnet_ids  = [data.aws_subnet.public1.id, data.aws_subnet.public2.id, data.aws_subnet.public3.id]
  }
}

# Data source for VPC
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["rv-dev-vpc"]
  }
}

# DB subnets (data subnets in CRI)
data "aws_subnet" "db1" {
  filter {
    name   = "tag:Name"
    values = ["dev-data-1"]
  }
}
data "aws_subnet" "db2" {
  filter {
    name   = "tag:Name"
    values = ["dev-data-2"]
  }
}
data "aws_subnet" "db3" {
  filter {
    name   = "tag:Name"
    values = ["dev-data-3"]
  }
}

# private subnets
data "aws_subnet" "private1" {
  filter {
    name   = "tag:Name"
    values = ["dev-private-1"]
  }
}
data "aws_subnet" "private2" {
  filter {
    name   = "tag:Name"
    values = ["dev-private-2"]
  }
}
data "aws_subnet" "private3" {
  filter {
    name   = "tag:Name"
    values = ["dev-private-3"]
  }
}

# public subnets
data "aws_subnet" "public1" {
  filter {
    name   = "tag:Name"
    values = ["dev-public-1"]
  }
}
data "aws_subnet" "public2" {
  filter {
    name   = "tag:Name"
    values = ["dev-public-2"]
  }
}
data "aws_subnet" "public3" {
  filter {
    name   = "tag:Name"
    values = ["dev-public-3"]
  }
}

# logicworks default KMS key
data "aws_kms_key" "ebs_key" {
  key_id = "alias/logicworksDefault"
}
