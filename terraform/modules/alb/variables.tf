variable "name" {
  type        = string
  description = "Prefix used to tag and name every resource this module creates."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet ids from the network module, for the internet-facing ALB."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids from the network module, for the internal ALB."
}

variable "public_alb_security_group_id" {
  type        = string
  description = "Security group id for the public ALB, from the security module."
}

variable "internal_alb_security_group_id" {
  type        = string
  description = "Security group id for the internal ALB, from the security module."
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = <<-EOT
    ACM certificate ARN used for the HTTPS listener on both ALBs. Leave empty
    to run HTTP only; issuing the certificate is a manual step outside this
    module.
  EOT
}
