account_number  = "164804042272"
region          = "us-east-1"
# private_subnets = ["data.aws_subnet.private1.id, data.aws_subnet.private2.id, data.aws_subnet.private3.id"]
# public_subnets  = ["data.aws_subnet.public1.id, data.aws_subnet.public2.id, data.aws_subnet.public3.id"]

app_routes = {
  # Example:
  # "customer-name" = {
  #   instance_key   = "customer-name"
  #   host_headers   = ["customer-name.hosted.reflectsystems.com"]
  #   priority       = 200
  #   backend_port   = 443
  #   backend_proto  = "HTTPS"
  #   health_path    = "/health"
  #   health_matcher = "200"
  # }
}
