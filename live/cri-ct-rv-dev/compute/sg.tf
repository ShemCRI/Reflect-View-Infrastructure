# Look up the ALB security group from the ALB stack
data "aws_security_group" "alb_sg" {
  filter {
    name   = "group-name"
    values = ["cri-ct-rv-dev-alb-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [local.networking.vpc_id]
  }
}

resource "aws_security_group" "app_ec2" {
  for_each = var.dev_ec2_instances

  name        = "${var.environment}-${each.key}-sg"
  description = "${each.key} EC2 - Managed by Terraform"
  vpc_id      = local.networking.vpc_id

  # HTTPS from ALB
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.aws_security_group.alb_sg.id]
    description     = "Allow HTTPS from ALB"
  }

  ingress {
    from_port   = 10933
    to_port     = 10933
    protocol    = "tcp"
    cidr_blocks = ["10.150.0.0/16"]
    description = "Allow Octopus"
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Allow RDP"
  }

  ingress {
    from_port   = 7777
    to_port     = 7777
    protocol    = "tcp"
    cidr_blocks = ["172.24.0.0/15"]
    description = "Allow AlertLogic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}
