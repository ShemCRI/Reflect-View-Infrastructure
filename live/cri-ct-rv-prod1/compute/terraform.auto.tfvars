account_number         = "109743757398"
region                 = "us-east-1"
keypair_name           = "cri-ct-rv-prod1-kp"
# private_subnets        = ["data.aws_subnet.private1.id, data.aws_subnet.private2.id, data.aws_subnet.private3.id"]
# default_security_group = []
root_ebs_type          = "gp3"
environment            = "prod1"

azure_ad_domain_name           = "hosted.reflectsystems.com"
azure_ad_dns_ips               = ["10.0.10.5", "10.0.10.4"]
azure_ad_ou_path               = "OU=AADDC Computers,DC=hosted,DC=reflectsystems,DC=com"
domain_join_username_parameter = "/cri/azure-ad/domain-join-username"
domain_join_password_parameter = "/cri/azure-ad/domain-join-password"

# Azure Automation DSC parameters
dsc_registration_url_parameter = "/cri/azure-dsc/registration-url"
dsc_registration_key_parameter = "/cri/azure-dsc/registration-key"
dsc_node_configuration_name    = "reflectview_saas_rv3_UTC_TLSHardened_2022.localhost"

prod1_ec2_instances = {
    "rv-prod1-ad-test" = {
        ami_id = "ami-0159172a5a821bafd"
        instance_type = "t3.medium"
        subnet_id = "subnet-08476614697a4c96b"
        root_ebs_size = 80
        root_ebs_type = "gp3"
        root_ebs_kms_key_arn = "arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89"
        deletion_protection = true
        user_data = ""
        tags = {    
            "Name" = "rv-prod1-ad-test"
        }
    }
}