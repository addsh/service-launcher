variable "name" {
  type        = string
  description = "Prefix used to tag and name every resource this module creates."
}

variable "create_database" {
  type        = bool
  default     = false
  description = <<-EOT
    Create the shared PostgreSQL instance. Costs money whether or not a
    service uses it; only enable this once a service needs it.
  EOT
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids from the network module, for the DB subnet group."
}

variable "database_security_group_id" {
  type        = string
  description = "Security group id for the database, from the security module."
}

variable "instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "Instance class for the PostgreSQL instance."
}

variable "database_name" {
  type        = string
  default     = "app"
  description = "Initial database name."
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GiB."
}

variable "engine_version" {
  type        = string
  default     = "16"
  description = <<-EOT
    PostgreSQL major version. Also selects the DB parameter group family,
    which must match.
  EOT
}
