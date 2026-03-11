variable "account_number" {
  description = "target account no"
}
variable "region" {
  description = "target region"
}
variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = []
}
variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
  default     = []
}
variable "environment" {
  description = "environment name"
  type        = string
}
variable "keypair_name" {
  type = string
}
variable "default_security_group" {
  description = "security group ids"
  type        = list(string)
}
variable "root_ebs_type" {
  description = "root ebs type"
  type        = string
}

### New VARS for OSS ###
variable "rds_instances" {
  description = "Map of client-ready RDS instances keyed by logical name."
  type = map(object({
    create_db_instance            = optional(bool, true)
    identifier                    = string
    create_db_option_group        = optional(bool, false)
    option_group_name             = optional(string, "cri-ct-rv-prod1-rds-optiongroup1")
    engine_version                = optional(string, "16.00.4205.1.v1")
    instance_class                = string
    username                      = optional(string, "admin")
    manage_master_user_password   = optional(bool, true)
    master_user_secret_kms_key_id = optional(string)
    kms_key_id                    = string
    allocated_storage             = number
    max_allocated_storage         = number
    iops                          = optional(number, 3000)
    maintenance_window            = optional(string, "Sun:00:00-Sun:03:00")
    backup_window                 = optional(string, "03:00-06:00")
    backup_retention_period       = optional(number, 30)
    monitoring_role_name          = optional(string)
    timezone                      = optional(string, "UTC")
    tags                          = optional(map(string), {})
  }))
  default = {}
}

locals {
  networking = {
    vpc_id        = data.aws_vpc.vpc.id
    db_subnet_ids = [data.aws_subnet.db1.id, data.aws_subnet.db2.id, data.aws_subnet.db3.id]
    #  private_subnet_ids = [data.aws_subnet.private1.id, data.aws_subnet.private2.id, data.aws_subnet.private3.id]
    #  public_subnet_ids  = [data.aws_subnet.public1.id, data.aws_subnet.public2.id, data.aws_subnet.public3.id]
  }
}
# Data source for VPC
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["rv-prod1-vpc"]
  }
}
#DB subnets (data subnets in CRI)
data "aws_subnet" "db1" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-1"]
  }
}
data "aws_subnet" "db2" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-2"]
  }
}
data "aws_subnet" "db3" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-3"]
  }
}
# private subnets
# data "aws_subnet" "private1" {
#   filter {
#     name   = "tag:Name"
#     values = ["prod1-private-1"]
#   }
# }
# data "aws_subnet" "private2" {
#   filter {
#     name   = "tag:Name"
#     values = ["prod1-private-2"]
#   }
# }
# data "aws_subnet" "private3" {
#   filter {
#     name   = "tag:Name"
#     values = ["prod1-private-3"]
#   }
# }



data "aws_subnet" "data1" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-1"]
  }
}
data "aws_subnet" "data2" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-2"]
  }
}
data "aws_subnet" "data3" {
  filter {
    name   = "tag:Name"
    values = ["prod1-data-3"]
  }
}