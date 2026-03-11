variable "environment" {
  description = "Environment name (e.g., prod1, staging)"
  type        = string
}

variable "document_name_prefix" {
  description = "Prefix for the SSM document name"
  type        = string
  default     = "azure-dsc-registration"
}

variable "registration_url_parameter" {
  description = "SSM Parameter Store name containing the Azure Automation DSC registration URL"
  type        = string
}

variable "registration_key_parameter" {
  description = "SSM Parameter Store name containing the Azure Automation DSC registration key (SecureString)"
  type        = string
}

variable "node_configuration_name" {
  description = "The DSC node configuration to apply to registered nodes (e.g., MyConfig.localhost)"
  type        = string
}

variable "configuration_mode" {
  description = "How the LCM applies the configuration: ApplyOnly, ApplyAndMonitor, or ApplyAndAutoCorrect"
  type        = string
  default     = "ApplyAndMonitor"

  validation {
    condition     = contains(["ApplyOnly", "ApplyAndMonitor", "ApplyAndAutoCorrect"], var.configuration_mode)
    error_message = "configuration_mode must be one of: ApplyOnly, ApplyAndMonitor, ApplyAndAutoCorrect"
  }
}

variable "configuration_mode_frequency_mins" {
  description = "How often (in minutes) DSC checks if the configuration is in the desired state"
  type        = number
  default     = 15
}

variable "refresh_frequency_mins" {
  description = "How often (in minutes) the LCM checks with Azure Automation for updated configurations"
  type        = number
  default     = 30
}

variable "reboot_if_needed" {
  description = "Whether to automatically reboot the node if required by the configuration"
  type        = bool
  default     = true
}

variable "target_tag_key" {
  description = "EC2 tag key to target for DSC registration"
  type        = string
  default     = "azure-dsc"
}

variable "target_tag_value" {
  description = "EC2 tag value to target for DSC registration"
  type        = string
  default     = "true"
}
