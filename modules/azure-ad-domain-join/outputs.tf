output "document_name" {
  description = "Name of the SSM document for Azure AD domain join"
  value       = aws_ssm_document.azure_ad_join.name
}

output "document_arn" {
  description = "ARN of the SSM document"
  value       = aws_ssm_document.azure_ad_join.arn
}

output "association_id" {
  description = "ID of the SSM association"
  value       = aws_ssm_association.azure_ad_join.association_id
}

output "target_tag" {
  description = "Tag key=value that instances need to be domain-joined"
  value       = "${var.target_tag_key}=${var.target_tag_value}"
}

