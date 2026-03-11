account_number         = "109743757398"
region                 = "us-east-1"
keypair_name           = "cri-ct-rv-prod1-kp"
private_subnets        = ["data.aws_subnet.private1.id, data.aws_subnet.private2.id, data.aws_subnet.private3.id"]
default_security_group = []
root_ebs_type          = "gp3"
environment            = "prod1"

rds_instances = {
  client01 = {
    identifier                    = "rv-prod01-shared-rds01"
    instance_class                = "db.t3.2xlarge"
    kms_key_id                    = "arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89"
    allocated_storage             = 100
    max_allocated_storage         = 500
    monitoring_role_name          = "sqlserver-rds-client01-monitoring-role"
    backup_retention_period       = 30
    manage_master_user_password   = true
    master_user_secret_kms_key_id = "arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89"
  }
}