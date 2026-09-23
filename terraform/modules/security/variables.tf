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

variable "services" {
  type = map(object({
    database = optional(bool, false)
    cache    = optional(bool, false)
  }))
  default     = {}
  description = <<-EOT
    Services map, used only for its database and cache booleans. A service
    with database or cache set to true gets its own security group. Ingress
    still comes from the one shared instance security group, since there is
    no per-service instance security group yet, so this does not isolate a
    service's database or cache from a compromised instance belonging to a
    different service; it only keeps each service's rules and resource on
    its own group instead of a single group shared by every database.
  EOT
}
