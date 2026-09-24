output "public_alb_dns_name" {
  value       = module.alb.public_alb_dns_name
  description = "DNS name of the public ALB. Point a domain's CNAME or alias here, or use it directly to reach public services before DNS is set up."
}

output "internal_alb_dns_name" {
  value       = module.alb.internal_alb_dns_name
  description = "DNS name of the internal ALB, reachable only from inside the VPC."
}

# Mirrors the host_header fallback in main.tf so this resolves to the same
# URL the listener rule actually matches on, whether or not a service set
# its own host_header.
output "service_urls" {
  value = {
    for name, service in var.services : name =>
    "${service.use_https ? "https" : "http"}://${coalesce(service.host_header, "${name}.${var.domain_name}")}"
  }
  description = "Expected URL per service. Only resolves once the host header's DNS record points at the right ALB; set hosted_zone_id on a service to have that record created automatically."
}
