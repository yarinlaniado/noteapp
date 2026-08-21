output "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state. Use this in other stacks' backend \"s3\" blocks."
  value       = aws_s3_bucket.state.bucket
}

output "aws_region" {
  description = "AWS region the state bucket was created in"
  value       = var.aws_region
}
