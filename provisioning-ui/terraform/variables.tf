variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID where resources will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the provisioning UI"
  type        = string
  default     = "t3.small"
}

variable "environment" {
  description = "Environment name (e.g., shared, dev, prod)"
  type        = string
  default     = "shared"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
