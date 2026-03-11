data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::786284303891:role/terraform-execute"
  }

  default_tags {
    tags = {
      "map-migrated" = "mig7NUU2YAD76"
    }
  }
}

#######################################
# S3 Bucket for DB Migrations
#######################################
module "db_migration_bucket" {
  source  = "code.logicworks.net/terraform-modules/terraform-aws-s3/aws"
  version = "0.10.1"

  name                       = "cri-rv-db-migrations"
  attach_bucket_policy       = true
  bucket_policy_json         = data.aws_iam_policy_document.db_migration_bucket_policy.json
  block_public_acls          = true
  block_public_policy        = true
  ignore_public_acls         = true
  restrict_public_buckets    = true
  default_bucket_key_enabled = true
  sse_algorithm              = "AES256"
  versioning_status          = "Enabled"

  tags = {
    "managed-by"  = "rs-terraform"
    "environment" = var.env_name
    "purpose"     = "db-migrations"
  }
}

#######################################
# Bucket Policy for Cross-Account Access
#######################################
data "aws_iam_policy_document" "db_migration_bucket_policy" {
  # Allow cross-account principals full access
  statement {
    sid    = "CrossAccountFullAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.cross_account_principals
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
      "s3:PutObjectAcl",
      "s3:GetObjectAcl"
    ]

    resources = [
      "arn:aws:s3:::cri-rv-db-migrations",
      "arn:aws:s3:::cri-rv-db-migrations/*"
    ]
  }

  # Deny unencrypted traffic
  statement {
    sid    = "DenyUnencryptedTraffic"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::cri-rv-db-migrations",
      "arn:aws:s3:::cri-rv-db-migrations/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

