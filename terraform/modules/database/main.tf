# Opt-in resource, so it gets the multi-AZ treatment per the CLAUDE.md rule
# for anything a user turns on deliberately: someone enabling a database is
# running something real, and a second instance is cheaper than the outage a
# single AZ would eventually cause. The instance class itself still defaults
# to the cheap db.t4g.micro.

locals {
  enabled = var.create_database ? 1 : 0
}

resource "aws_db_subnet_group" "this" {
  count = local.enabled

  name       = "${var.name}-database"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name}-database"
  }
}

# rds.force_ssl rejects any connection that does not negotiate TLS.
# storage_encrypted below only covers data at rest; without this, a client
# can still connect in plaintext.
resource "aws_db_parameter_group" "this" {
  count = local.enabled

  name   = "${var.name}-postgres"
  family = "postgres${var.engine_version}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  count = local.enabled

  identifier     = "${var.name}-database"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.database_name
  username = "postgres"

  # manage_master_user_password puts the credential straight into Secrets
  # Manager and rotates it, so there is no secret resource to declare or
  # attach separately, unlike the CloudFormation version which builds the
  # secret by hand.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  parameter_group_name   = aws_db_parameter_group.this[0].name
  vpc_security_group_ids = [var.database_security_group_id]

  multi_az                = true
  publicly_accessible     = false
  backup_retention_period = 7
  deletion_protection     = false

  # This account gets torn down and redeployed most sessions per the README
  # cost guidance, so a final snapshot would just accumulate storage cost
  # and, worse, collide with the fixed identifier on the next destroy. A
  # production account kept running long-term should flip this and name a
  # unique final_snapshot_identifier instead.
  skip_final_snapshot = true

  tags = {
    Name = "${var.name}-database"
  }
}
