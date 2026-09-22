# Chain: internet -> public ALB -> instances -> database. Each group only
# opens ports to the specific group in front of it, per the narrowest-scope
# rule in CLAUDE.md, rather than to a CIDR range that would also let
# instances reach each other directly.
#
# Every rule below is a separate aws_vpc_security_group_ingress_rule or
# aws_vpc_security_group_egress_rule resource rather than an inline block,
# so the instance and database groups can reference each other's id without
# the two aws_security_group resources depending on each other directly.

resource "aws_security_group" "public_alb" {
  name        = "${var.name}-public-alb"
  description = "Public ALB, open to the internet on HTTP and HTTPS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-public-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_alb_http" {
  security_group_id = aws_security_group.public_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "public_alb_https" {
  security_group_id = aws_security_group.public_alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "public_alb_to_instances" {
  security_group_id = aws_security_group.public_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
  description       = "Forward to service instances"
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.name}-internal-alb"
  description = "Internal ALB, open to the VPC on HTTP and HTTPS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-internal-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_http" {
  security_group_id = aws_security_group.internal_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_https" {
  security_group_id = aws_security_group.internal_alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_instances" {
  security_group_id = aws_security_group.internal_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
  description       = "Forward to service instances"
}

resource "aws_security_group" "instance" {
  name        = "${var.name}-instance"
  description = "Service instances, open only to the two ALBs"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-instance"
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_from_public_alb" {
  security_group_id            = aws_security_group.instance.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.public_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "instance_from_internal_alb" {
  security_group_id            = aws_security_group.instance.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_egress_rule" "instance_to_vpc_endpoints" {
  security_group_id = aws_security_group.instance.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
  description       = "SSM, ssmmessages, ec2messages interface endpoints"
}

resource "aws_vpc_security_group_egress_rule" "instance_internet_http" {
  count = var.enable_nat_gateway ? 1 : 0

  security_group_id = aws_security_group.instance.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Internet egress via NAT Gateway"
}

resource "aws_vpc_security_group_egress_rule" "instance_internet_https" {
  count = var.enable_nat_gateway ? 1 : 0

  security_group_id = aws_security_group.instance.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Internet egress via NAT Gateway"
}

resource "aws_vpc_security_group_egress_rule" "instance_to_database" {
  security_group_id            = aws_security_group.instance.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.database.id
  description                  = "PostgreSQL"
}

# A database has no reason to originate outbound traffic. There is no
# egress rule resource for this group on purpose: aws_security_group
# removes the AWS-created allow-all egress rule as soon as it manages a
# group at all, so declaring zero egress rules here is enough to deny all
# outbound, unlike CloudFormation which needs an explicit placeholder rule
# to get the same result.
resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "PostgreSQL, open only to service instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-database"
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_instances" {
  security_group_id            = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.instance.id
}
