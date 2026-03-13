resource "aws_kms_key" "this" {
  description             = "KMS key for the EBS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    Name = "cri-ct-rv-dev-ebs-kms-key"
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/cri-ct-rv-dev-ebs-kms-key"
  target_key_id = aws_kms_key.this.key_id
}
