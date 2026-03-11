variable "environment" {
  description = "Environment name used for naming resources (e.g., prod1, staging, dev)"
  type        = string
}

variable "domain_name" {
  description = "Azure AD DS domain name (e.g., hosted.reflectsystems.com)"
  type        = string
}

variable "dns_ips" {
  description = "List of Azure AD DS DNS server IP addresses"
  type        = list(string)

  validation {
    condition     = length(var.dns_ips) >= 1 && length(var.dns_ips) <= 2
    error_message = "Must provide 1 or 2 DNS IP addresses."
  }
}

variable "ou_path" {
  description = "Target OU distinguished name for domain join (e.g., OU=AADDC Computers,DC=hosted,DC=reflectsystems,DC=com)"
  type        = string
}

variable "username_parameter_name" {
  description = "SSM Parameter Store name containing the domain join username (must be in UPN format: user@domain.com)"
  type        = string
}

variable "password_parameter_name" {
  description = "SSM Parameter Store name containing the domain join password (SecureString)"
  type        = string
}

variable "target_tag_key" {
  description = "Tag key used to target instances for domain join"
  type        = string
  default     = "azure-ad-join"
}

variable "target_tag_value" {
  description = "Tag value used to target instances for domain join"
  type        = string
  default     = "true"
}

variable "document_name_prefix" {
  description = "Prefix for the SSM document name"
  type        = string
  default     = "azure-ad-join-domain"
}

