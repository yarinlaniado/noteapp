data "aws_caller_identity" "current" {}

resource "aws_dynamodb_table" "notes" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "noteapp"
  }
}

resource "aws_s3_bucket" "images" {
  # Region is baked into the name: S3 bucket names are globally unique, so a
  # future region move needs a new name anyway (this also avoids any collision
  # with a bucket of the same base name left over in a previous region).
  bucket = "${var.bucket_name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Project = "noteapp"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Non-prod data store, shared by every ephemeral branch environment (not
# one per branch) — so a broken feature-branch deploy can never touch real
# production notes/images. IRSA trust policies enforce which role can reach
# which of these two stores (see terraform/eks/irsa.tf).

resource "aws_dynamodb_table" "notes_nonprod" {
  name         = "${var.table_name}-nonprod"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "noteapp"
    Purpose = "ephemeral-env-data"
  }
}

resource "aws_s3_bucket" "images_nonprod" {
  bucket = "${var.bucket_name_prefix}-nonprod-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Project = "noteapp"
    Purpose = "ephemeral-env-data"
  }
}

resource "aws_s3_bucket_public_access_block" "images_nonprod" {
  bucket = aws_s3_bucket.images_nonprod.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images_nonprod" {
  bucket = aws_s3_bucket.images_nonprod.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
