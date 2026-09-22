output "bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "Pass this into envs/example/backend.tf as the backend bucket."
}
