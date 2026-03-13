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

# Read EC2 instance details from the compute stack's remote state
data "terraform_remote_state" "compute" {
  backend = "s3"

  config = {
    bucket = "cri-terraform-state-backend"
    region = "us-east-1"
    key    = "cri-ct-rv-dev/compute/terraform.tfstate"
  }
}

locals {
  app_route_keys = sort(keys(var.app_routes))

  app_route_listener_rules = [
    for route_index, route_key in local.app_route_keys : {
      https_listener_index = 0
      priority             = var.app_routes[route_key].priority
      actions = [{
        type               = "forward"
        target_group_index = route_index
      }]
      conditions = [{
        host_headers = var.app_routes[route_key].host_headers
      }]
    }
  ]

  app_route_target_groups = [
    for route_key in local.app_route_keys : {
      name_prefix      = "${substr(route_key, 0, 3)}${substr(md5(route_key), 0, 2)}-"
      target_type      = "instance"
      backend_port     = var.app_routes[route_key].backend_port
      backend_protocol = var.app_routes[route_key].backend_proto

      targets = {
        (route_key) = {
          target_id = data.terraform_remote_state.compute.outputs.dev_ec2_instances[var.app_routes[route_key].instance_key]
          port      = var.app_routes[route_key].backend_port
        }
      }

      health_check = {
        protocol = var.app_routes[route_key].backend_proto
        path     = var.app_routes[route_key].health_path
        matcher  = var.app_routes[route_key].health_matcher
      }
    }
  ]
}

module "alb_shared_dev" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.7.0"
  name    = "rv-dev-shared-alb1"

  vpc_id                     = local.networking.vpc_id
  subnets                    = local.networking.public_subnet_ids
  security_groups            = [module.alb_sg.security_group_id]
  create_security_group      = false
  enable_deletion_protection = false  # Dev environment - allow deletion
  load_balancer_type         = "application"
  internal                   = false

  access_logs = {
    enabled = true
    bucket  = aws_s3_bucket.alb_access_logs.bucket
    prefix  = "rv-dev-shared-alb1"
  }

  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.reflectsystems_wildcard.arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "text/html"
        message_body = "<html><body><h1>Service Unavailable</h1><p>No application route matched on this shared ALB.</p></body></html>"
        status_code  = "404"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        protocol    = "HTTPS"
        port        = "443"
        status_code = "HTTP_301"
      }
    }
  ]

  # Shared ALB URL routing rules
  https_listener_rules = local.app_route_listener_rules

  target_groups = local.app_route_target_groups
}
