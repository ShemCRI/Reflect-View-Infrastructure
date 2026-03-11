resource "aws_security_group" "sg_rds" {
  name        = "${var.environment}-rds-sg"
  description = "RDS - Managed by Terraform"
  vpc_id      = local.networking.vpc_id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["10.11.18.0/24"]
    description = "prod private01"
  }

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["10.11.19.0/24"]
    description = "prod private02"
  }

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["10.12.0.0/22"]
    description = "Client VPN"
  }

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["72.74.35.220/32"]
    description = "kevin ip"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}