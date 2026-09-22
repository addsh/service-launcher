variable "name" {
  type        = string
  description = "Prefix used to tag and name every resource this module creates."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
  description = "CIDR blocks for the two public subnets, one per AZ."

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must have exactly two entries, one per AZ."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  description = "CIDR blocks for the two private subnets, one per AZ."

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must have exactly two entries, one per AZ."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = <<-EOT
    Give private subnets outbound internet access through a NAT Gateway, one
    per AZ so egress stays inside the AZ instead of crossing to a shared
    gateway. Costs money whether or not it is used. VPC endpoints cover SSM
    and S3 without it; only enable this if a service needs to reach the
    open internet.
  EOT
}

variable "enable_ssm_endpoints" {
  type        = bool
  default     = false
  description = <<-EOT
    Create interface VPC endpoints for ssm, ssmmessages, and ec2messages, so
    Session Manager reaches private instances without a NAT Gateway. Billed
    per AZ per hour plus data processed, so this defaults off; the
    CloudFormation version creates these unconditionally, this port makes
    the cost opt-in instead.
  EOT
}
