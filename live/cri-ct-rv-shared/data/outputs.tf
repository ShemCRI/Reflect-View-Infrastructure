output "db_migration_bucket_name" {
  description = "Name of the DB migration S3 bucket"
  value       = module.db_migration_bucket.bucket_id
}

output "db_migration_bucket_arn" {
  description = "ARN of the DB migration S3 bucket"
  value       = module.db_migration_bucket.bucket_arn
}