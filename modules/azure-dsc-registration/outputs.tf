output "ssm_document_name" {
  description = "Name of the SSM document for DSC registration"
  value       = aws_ssm_document.dsc_registration.name
}

output "ssm_document_arn" {
  description = "ARN of the SSM document for DSC registration"
  value       = aws_ssm_document.dsc_registration.arn
}

output "ssm_association_id" {
  description = "ID of the SSM association for DSC registration"
  value       = aws_ssm_association.dsc_registration.association_id
}

output "target_tag" {
  description = "Tag key and value used to target instances for DSC registration"
  value = {
    key   = var.target_tag_key
    value = var.target_tag_value
  }
}

