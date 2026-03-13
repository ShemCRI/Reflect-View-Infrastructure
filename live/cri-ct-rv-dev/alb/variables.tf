variable "account_number" {
  description = "target account no"
}
variable "region" {
  description = "target region"
}

variable "app_routes" {
  description = "Per-app ALB routing config keyed by app name (for example: app1, app2)"
  type = map(object({
    instance_key   = string
    host_headers   = list(string)
    priority       = number
    backend_port   = number
    backend_proto  = string
    health_path    = string
    health_matcher = string
  }))
  default = {}

  validation {
    condition     = alltrue([for route in values(var.app_routes) : length(route.host_headers) > 0])
    error_message = "Each app route must include at least one host header."
  }

  validation {
    condition     = length(distinct([for route in values(var.app_routes) : route.priority])) == length(values(var.app_routes))
    error_message = "Each app route priority must be unique."
  }

  validation {
    condition     = alltrue([for route in values(var.app_routes) : route.priority >= 1 && route.priority <= 50000])
    error_message = "Each app route priority must be between 1 and 50000."
  }

  validation {
    condition     = alltrue([for route in values(var.app_routes) : contains(["HTTP", "HTTPS"], upper(route.backend_proto))])
    error_message = "Each app route backend_proto must be HTTP or HTTPS."
  }
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
