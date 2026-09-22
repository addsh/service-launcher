variable "name" {
  type        = string
  description = "Prefix used to tag and name every security group this module creates."
}

variable "vpc_id" {
  type        = string
  description = "VPC id from the network module."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block from the network module, used to scope rules to inside the VPC."
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Whether a NAT Gateway exists, so instances get outbound internet egress on 80/443. Must match the network module's enable_nat_gateway."
}
