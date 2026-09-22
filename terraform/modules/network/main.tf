data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Keyed by AZ, not index, so a subnet never gets recreated just because
  # another one shifted position in the list.
  public_subnets_by_az  = zipmap(local.azs, var.public_subnet_cidrs)
  private_subnets_by_az = zipmap(local.azs, var.private_subnet_cidrs)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets_by_az

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets_by_az

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One route table per AZ so each private subnet can get its own NAT Gateway,
# matching the per-AZ NAT Gateway below instead of forcing both AZs through
# one shared table.
resource "aws_route_table" "private" {
  for_each = local.private_subnets_by_az

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# One NAT Gateway per AZ, each with its own EIP, so private subnets egress
# within their own AZ rather than crossing AZs to a single shared gateway.
# This doubles the NAT Gateway hourly charge versus one shared gateway,
# accepted per the multi-AZ rule for opt-in resources in CLAUDE.md.
resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? local.private_subnets_by_az : {}

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? local.private_subnets_by_az : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.private_subnets_by_az : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# Gateway endpoint, no hourly charge. Covers S3 access from every route
# table so instances without a NAT Gateway can still pull from S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.private : rt.id],
  )
}

# Interface endpoints, billed per AZ per hour plus data processed. These
# three let instances in private subnets reach SSM for Session Manager
# access, replacing a bastion or NAT, without a NAT Gateway. No inline
# egress block here: omitting it lets the AWS-created allow-all egress rule
# stand, which is fine since these endpoint ENIs never originate traffic.
resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name        = "${var.name}-vpce"
  description = "Allow HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-vpce"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.enable_ssm_endpoints ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

locals {
  interface_endpoint_services = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
}
