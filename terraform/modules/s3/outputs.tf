output "bucket_names" {
  description = "S3 bucket names"
  value       = aws_s3_bucket.main[*].id
}

output "bucket_arns" {
  description = "S3 bucket ARNs"
  value       = aws_s3_bucket.main[*].arn
}
