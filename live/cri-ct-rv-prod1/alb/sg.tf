module "alb_sg" {
  source      = "code.logicworks.net/terraform-modules/terraform-aws-securitygroup/aws"
  version     = "1.3.2"
  vpc_id      = local.networking.vpc_id
  name        = "cri-ct-rv-prod1-alb-sg"
  description = "Security group for the ALB"
  ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress_rules = {
    all = {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

module "alb_yme_sg" {
  source      = "code.logicworks.net/terraform-modules/terraform-aws-securitygroup/aws"
  version     = "1.3.2"
  vpc_id      = local.networking.vpc_id
  name        = "rv-prod1-alb-sg"
  description = "Security group for rv-prod1 ALB"
  ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress_rules = {
    all = {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}