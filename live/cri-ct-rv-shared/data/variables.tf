variable "region" {
  type        = string
  description = "Region to deploy resources"
}

variable "env_name" {
  type        = string
  description = "Name of the environment"
}

variable "cross_account_principals" {
  type        = list(string)
  description = "List of AWS account IDs or IAM role ARNs that need access to the S3 bucket"
  default     = []
}

