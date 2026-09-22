variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket that holds Terraform state. Must be globally unique."
}

variable "region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region for the state bucket."
}
