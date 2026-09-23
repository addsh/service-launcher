module "network" {
  source = "../../modules/network"

  name                 = var.name
  enable_nat_gateway   = var.enable_nat_gateway
  enable_ssm_endpoints = var.enable_ssm_endpoints
}

module "security" {
  source = "../../modules/security"

  name               = var.name
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
}

module "alb" {
  source = "../../modules/alb"

  name                           = var.name
  public_subnet_ids              = module.network.public_subnet_ids
  private_subnet_ids             = module.network.private_subnet_ids
  public_alb_security_group_id   = module.security.public_alb_security_group_id
  internal_alb_security_group_id = module.security.internal_alb_security_group_id
  certificate_arn                = var.certificate_arn
}

module "database" {
  source = "../../modules/database"

  name                       = var.name
  create_database            = var.create_database
  private_subnet_ids         = module.network.private_subnet_ids
  database_security_group_id = module.security.database_security_group_id
}

module "service" {
  source   = "../../modules/service"
  for_each = var.services

  name                       = each.key
  vpc_id                     = module.network.vpc_id
  instance_security_group_id = module.security.instance_security_group_id
  private_subnet_ids         = module.network.private_subnet_ids

  exposure  = each.value.exposure
  use_https = each.value.use_https

  public_http_listener_arn    = module.alb.public_http_listener_arn
  public_https_listener_arn   = module.alb.public_https_listener_arn
  internal_http_listener_arn  = module.alb.internal_http_listener_arn
  internal_https_listener_arn = module.alb.internal_https_listener_arn
  public_alb_dns_name         = module.alb.public_alb_dns_name
  public_alb_zone_id          = module.alb.public_alb_zone_id
  internal_alb_dns_name       = module.alb.internal_alb_dns_name
  internal_alb_zone_id        = module.alb.internal_alb_zone_id

  host_header = coalesce(each.value.host_header, "${each.key}.${var.domain_name}")
  priority    = local.service_priorities[each.key]

  port                   = each.value.port
  health_check_path      = each.value.health_check_path
  instance_type          = each.value.instance_type
  root_volume_size       = each.value.root_volume_size
  min_size               = each.value.min_size
  max_size               = each.value.max_size
  target_cpu_utilization = each.value.target_cpu_utilization
  hosted_zone_id         = each.value.hosted_zone_id
}
