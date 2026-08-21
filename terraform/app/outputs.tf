output "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing notes"
  value       = aws_dynamodb_table.notes.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table storing notes (consumed by terraform/eks IRSA policies)"
  value       = aws_dynamodb_table.notes.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing note images"
  value       = aws_s3_bucket.images.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing note images (consumed by terraform/eks IRSA policies)"
  value       = aws_s3_bucket.images.arn
}

output "dynamodb_table_nonprod_name" {
  description = "Name of the DynamoDB table shared by ephemeral branch environments"
  value       = aws_dynamodb_table.notes_nonprod.name
}

output "dynamodb_table_nonprod_arn" {
  description = "ARN of the DynamoDB table shared by ephemeral branch environments"
  value       = aws_dynamodb_table.notes_nonprod.arn
}

output "s3_bucket_nonprod_name" {
  description = "Name of the S3 bucket shared by ephemeral branch environments"
  value       = aws_s3_bucket.images_nonprod.bucket
}

output "s3_bucket_nonprod_arn" {
  description = "ARN of the S3 bucket shared by ephemeral branch environments"
  value       = aws_s3_bucket.images_nonprod.arn
}

output "aws_region" {
  description = "AWS region the resources were created in"
  value       = var.aws_region
}
