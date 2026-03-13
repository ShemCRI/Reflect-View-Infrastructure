module "alb_sg" {
  source      = "code.logicworks.net/terraform-modules/terraform-aws-securitygroup/aws"
  version     = "1.3.2"
  vpc_id      = local.networking.vpc_id
  name        = "cri-ct-rv-dev-alb-sg"
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
