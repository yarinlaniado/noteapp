variable "aws_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "eu-north-1"
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket that stores Terraform state (the account ID is appended to keep it globally unique)"
  type        = string
  default     = "noteapp-tfstate"
}
