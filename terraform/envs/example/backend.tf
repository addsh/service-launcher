# Fill in bucket with the value of the bucket_name output from
# terraform/bootstrap after applying it once. use_lockfile enables S3's
# native locking, so this needs no DynamoDB table; that mechanism is
# deprecated for new configurations.
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_YOUR_STATE_BUCKET"
    key          = "service-launcher/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
