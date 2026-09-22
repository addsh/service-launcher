# This config has no backend block on purpose: it creates the bucket that
# every other config in this repo uses for remote state, so its own state
# has to live somewhere else. Run it once with local state, keep the
# resulting terraform.tfstate file safe, and do not migrate it into the
# bucket it manages.

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  # Deleting this bucket by accident takes every other config's state with
  # it, so require it to be emptied by hand before Terraform will remove it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
