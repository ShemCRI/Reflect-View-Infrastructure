account_number         = "164804042272"
region                 = "us-east-1"
keypair_name           = "cri-ct-rv-dev-kp"
root_ebs_type          = "gp3"
environment            = "dev"

azure_ad_domain_name           = "hosted.reflectsystems.com"
azure_ad_dns_ips               = ["10.0.10.5", "10.0.10.4"]
azure_ad_ou_path               = "OU=AADDC Computers,DC=hosted,DC=reflectsystems,DC=com"
domain_join_username_parameter = "/cri/azure-ad/domain-join-username"
domain_join_password_parameter = "/cri/azure-ad/domain-join-password"

# Azure Automation DSC parameters
dsc_registration_url_parameter = "/cri/azure-dsc/registration-url"
dsc_registration_key_parameter = "/cri/azure-dsc/registration-key"
dsc_node_configuration_name    = "reflectview_saas_rv3_UTC_TLSHardened_2022.localhost"

# EC2 instances - add new customer instances here
dev_ec2_instances = {
  # Example:
  # "customer-name" = {
  #   ami_id               = "ami-0159172a5a821bafd"
  #   instance_type        = "t3.medium"
  #   subnet_id            = "subnet-08476614697a4c96b"
  #   root_ebs_size        = 80
  #   root_ebs_type        = "gp3"
  #   root_ebs_kms_key_arn = aws_kms_key.this.arn
  #   deletion_protection  = true
  #   user_data = <<-EOF
  #     <powershell>
  #     $desiredName = "customer-name"
  #     if ($env:COMPUTERNAME -ne $desiredName) {
  #       Rename-Computer -NewName $desiredName -Force -Restart
  #     }
  #     </powershell>
  #   EOF
  #   tags = {
  #     "Name" = "customer-name"
  #     "Customer" = "Customer Name"
  #     "Environment" = "cri-ct-rv-dev"
  #     "ManagedBy" = "Terraform"
  #   }
  # }
}
