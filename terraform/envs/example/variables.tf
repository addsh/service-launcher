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
# mirror services.yaml in the CloudFormation version; database and cache
# are not wired here yet, and compute is validated but only ec2 is built.
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
    # ec2 or ecs. Only ec2 is wired up so far; modules/ecs-service does not
    # exist yet.
    compute = optional(string, "ec2")
    # Listener rule priority. Must be unique per listener. Leave unset to
    # have it derived from sorted service names within the same exposure;
    # set it explicitly only when a service needs a stable priority across
    # additions and removals of other services.
    priority = optional(number)
  }))
  default     = {}
  description = "Services to deploy, keyed by service name."

  # Mirrors what generate.py checks for the CloudFormation version.
  validation {
    condition = alltrue([
      for name, service in var.services :
      # AWS target group names cap at 32 characters and this module appends
      # "-tg", so the service name itself is capped at 29.
      can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,27}[A-Za-z0-9])?$", name))
    ])
    error_message = "service names must be 1-29 characters, alphanumeric with hyphens, and not start or end with a hyphen."
  }

  validation {
    condition = alltrue([
      for name, service in var.services : contains(["public", "internal"], service.exposure)
    ])
    error_message = "exposure must be either \"public\" or \"internal\"."
  }

  validation {
    condition = alltrue([
      for name, service in var.services : contains(["ec2", "ecs"], service.compute)
    ])
    error_message = "compute must be either \"ec2\" or \"ecs\"."
  }

  validation {
    condition = alltrue([
      for exposure in ["public", "internal"] :
      length([for name, service in var.services : name if service.exposure == exposure]) <= 95
    ])
    error_message = "no more than 95 services may share the same exposure; that is the default ALB per-listener rule quota, with headroom left for the default rule and manual additions."
  }
}
