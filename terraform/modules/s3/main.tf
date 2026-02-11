# =============================================================================
# S3 Module
# =============================================================================

resource "aws_s3_bucket" "main" {
  count  = length(var.bucket_names)
  bucket = var.bucket_names[count.index]

  tags = merge(var.tags, {
    Name = var.bucket_names[count.index]
  })
}

resource "aws_s3_bucket_public_access_block" "main" {
  count  = length(var.bucket_names)
  bucket = aws_s3_bucket.main[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "main" {
  count  = var.enable_versioning ? length(var.bucket_names) : 0
  bucket = aws_s3_bucket.main[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count  = length(var.bucket_names)
  bucket = aws_s3_bucket.main[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = var.enable_lifecycle ? length(var.bucket_names) : 0
  bucket = aws_s3_bucket.main[count.index].id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration_days
    }
  }
}
