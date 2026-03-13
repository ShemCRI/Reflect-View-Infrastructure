resource "aws_s3_bucket" "alb_access_logs" {
  bucket = "rv-dev-s3-alb"
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

data "aws_iam_policy_document" "alb_access_logs_bucket_policy" {
  statement {
    sid     = "AllowAlbLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [
      aws_s3_bucket.alb_access_logs.arn
    ]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid     = "AllowAlbLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.alb_access_logs.arn}/rv-dev-shared-alb*/AWSLogs/${var.account_number}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id
  policy = data.aws_iam_policy_document.alb_access_logs_bucket_policy.json
}
