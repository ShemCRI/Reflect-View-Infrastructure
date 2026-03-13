output "dev_ec2_instances" {
  description = "Map of instance IDs keyed by dev EC2 instance identifier"
  value       = { for name, module_ref in module.app_ec2_instances : name => module_ref.id }
}
