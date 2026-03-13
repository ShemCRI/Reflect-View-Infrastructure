resource "aws_acm_certificate" "reflectsystems_wildcard" {
  domain_name = "reflectsystems.com"
  subject_alternative_names = [
    "*.reflectsystems.com",
    "*.hosted.reflectsystems.com"
  ]
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}
