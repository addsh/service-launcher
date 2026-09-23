variable "name" {
  type        = string
  description = "Prefix used to tag and name every resource this module creates, typically the service name."
}

variable "create_cache" {
  type        = bool
  default     = false
  description = "Create the Valkey cluster. Costs money whether or not a service uses it; only enable this once a service needs it."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids from the network module, for the cache subnet group."
}

variable "cache_security_group_id" {
  type        = string
  description = "Security group id for the cache, from the security module."
}

variable "node_type" {
  type        = string
  default     = "cache.t4g.micro"
  description = "Node type for the Valkey cluster."
}

variable "engine_version" {
  type        = string
  default     = "7.2"
  description = "Valkey engine version."
}
