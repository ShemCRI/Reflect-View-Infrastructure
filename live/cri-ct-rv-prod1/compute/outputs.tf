output "yme_instance_id" {
  description = "Instance ID of the aws-rv3-yme server"
  value       = module.aws_rv3_yme.instance_id
}

output "prod1_ec2_instances" {
  description = "Map of instance IDs keyed by prod1 EC2 instance identifier"
  value       = { for name, module_ref in module.app_ec2_instances : name => module_ref.id }
}
