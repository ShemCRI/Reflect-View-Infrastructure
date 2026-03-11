provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_number}:role/terraform-execute"
  }

  default_tags {
    tags = {
      "map-migrated" = "mig7NUU2YAD76"
    }
  }
}

module "rds_mssql_final" {
  source                    = "terraform-aws-modules/rds/aws"
  version                   = "6.12.0"
  identifier                = "cri-ct-rv-prod1-rds"
  create_db_instance        = true
  create_db_option_group    = false
  create_db_subnet_group    = true
  create_db_parameter_group = true
  skip_final_snapshot       = false
  deletion_protection       = true
  apply_immediately         = true
  multi_az                  = false
  engine                    = "sqlserver-se"
  engine_version            = "16.00.4205.1.v1"
  family                    = "sqlserver-se-16.0" # DB parameter group
  instance_class            = "db.m6i.large"
  username                  = "admin"
  storage_encrypted         = true
  kms_key_id                = "arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89"
  allocated_storage         = 200
  max_allocated_storage     = 400
  storage_type              = "gp3"
  iops                      = "3000"
  port                      = 1433
  # Self-managed Active Directory settings (uncomment when AD is ready)
  # domain_auth_secret_arn                = "arn:aws:secretsmanager:us-east-1:109743757398:secret:active-directory-service-acct-ZIwLSA"
  # domain_dns_ips                        = ["10.0.10.5", "10.0.10.4"]
  # domain_fqdn                           = "hosted.reflectsystems.com"
  # domain_ou                             = "OU=RDSInstances,DC=hosted,DC=reflectsystems,DC=com"
  subnet_ids                            = [data.aws_subnet.data1.id, data.aws_subnet.data2.id, data.aws_subnet.data3.id]
  vpc_security_group_ids                = [aws_security_group.sg_rds.id]
  maintenance_window                    = "Sun:00:00-Sun:03:00"
  backup_window                         = "03:00-06:00"
  backup_retention_period               = 3
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_role_name                  = "sqlserver-rds-monitoring-role"
  monitoring_interval                   = 60
  license_model                         = "license-included"
  timezone                              = "Eastern Standard Time"
  parameters = [
    {
      apply_method = "immediate"
      name         = "contained database authentication"
      value        = "1"
    }
  ]
  tags = {}
}
module "rds_mssql_client_ready" {
  for_each                              = var.rds_instances
  source                                = "terraform-aws-modules/rds/aws"
  version                               = "6.12.0"
  create_db_instance                    = each.value.create_db_instance
  identifier                            = each.value.identifier
  create_db_option_group                = each.value.create_db_option_group
  option_group_name                     = each.value.create_db_option_group ? null : each.value.option_group_name
  create_db_subnet_group                = true
  create_db_parameter_group             = true
  skip_final_snapshot                   = false
  deletion_protection                   = true
  apply_immediately                     = true
  multi_az                              = false
  engine                                = "sqlserver-se"
  engine_version                        = each.value.engine_version
  family                                = "sqlserver-se-16.0"
  instance_class                        = each.value.instance_class
  username                              = each.value.username
  manage_master_user_password           = each.value.manage_master_user_password
  master_user_secret_kms_key_id         = try(each.value.master_user_secret_kms_key_id, null)
  storage_encrypted                     = true
  kms_key_id                            = each.value.kms_key_id
  allocated_storage                     = each.value.allocated_storage
  max_allocated_storage                 = each.value.max_allocated_storage
  storage_type                          = "gp3"
  iops                                  = each.value.iops
  port                                  = 1433
  subnet_ids                            = [data.aws_subnet.data1.id, data.aws_subnet.data2.id, data.aws_subnet.data3.id]
  vpc_security_group_ids                = [aws_security_group.sg_rds.id]
  maintenance_window                    = each.value.maintenance_window
  backup_window                         = each.value.backup_window
  backup_retention_period               = each.value.backup_retention_period
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_role_name                  = coalesce(try(each.value.monitoring_role_name, null), "sqlserver-rds-${each.key}-monitoring-role")
  monitoring_interval                   = 60
  license_model                         = "license-included"
  timezone                              = each.value.timezone
  parameters = [
    {
      apply_method = "immediate"
      name         = "contained database authentication"
      value        = "1"
    }
  ]
  tags = each.value.tags
}