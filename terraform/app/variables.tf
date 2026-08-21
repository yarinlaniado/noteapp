variable "aws_region" {
  description = "AWS region to deploy the noteapp storage backend into"
  type        = string
  default     = "eu-north-1"
}

variable "table_name" {
  description = "Name of the DynamoDB table that stores notes"
  type        = string
  default     = "noteapp-notes"
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket that stores note images (the account ID is appended to keep it globally unique)"
  type        = string
  default     = "noteapp-images"
}
