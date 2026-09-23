variable "region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region for every resource in this config."
}

variable "name" {
  type        = string
  default     = "launcher"
  description = "Prefix used to tag and name shared resources: VPC, ALBs, database."
}

variable "domain_name" {
  type        = string
  description = "Domain used to build a service's default host header when it does not set one, as <service name>.<domain_name>."
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for the HTTPS listener on both ALBs. Leave empty to run HTTP only."
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Give private subnets outbound internet access through a NAT Gateway, one per AZ. Costs money; only enable it if a service needs to reach the open internet."
}

variable "enable_ssm_endpoints" {
  type        = bool
  default     = false
  description = "Create interface VPC endpoints for ssm, ssmmessages, and ec2messages, so Session Manager reaches private instances without a NAT Gateway."
}

variable "create_database" {
  type        = bool
  default     = false
  description = "Create the shared PostgreSQL instance. Costs money whether or not a service uses it."
}

# Each key is the service name, used to tag and name that service's
# resources and, by default, to derive its listener rule priority. Fields
# mirror services.yaml in the CloudFormation version; database, cache, and
# compute are not wired here yet.
variable "services" {
  type = map(object({
    port                   = optional(number, 80)
    health_check_path      = optional(string, "/")
    host_header            = optional(string)
    exposure               = optional(string, "public")
    use_https              = optional(bool, false)
    instance_type          = optional(string, "t3.micro")
    root_volume_size       = optional(number, 8)
    min_size               = optional(number, 1)
    max_size               = optional(number, 3)
    target_cpu_utilization = optional(number, 60)
    hosted_zone_id         = optional(string)
    # Listener rule priority. Must be unique per listener. Leave unset to
    # have it derived from sorted service names within the same exposure;
    # set it explicitly only when a service needs a stable priority across
    # additions and removals of other services.
    priority = optional(number)
  }))
  default     = {}
  description = "Services to deploy, keyed by service name."
}
