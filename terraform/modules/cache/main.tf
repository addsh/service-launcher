# Single-node, not Multi-AZ, unlike modules/database. A cache holds derived
# data the application can repopulate; losing the node costs a cache-warming
# period, not data, so the second node's cost is not worth paying by default
# even though the cache is opt-in.
#
# at_rest and transit encryption only exist on aws_elasticache_replication_group,
# not on the plain cluster resource, so a replication group is used here even
# though this is a single node.

locals {
  enabled = var.create_cache ? 1 : 0
}

resource "aws_elasticache_subnet_group" "this" {
  count = local.enabled

  name       = "${var.name}-cache"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  count = local.enabled

  replication_group_id = "${var.name}-cache"
  description          = "Single-node Valkey cluster for ${var.name}"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = 1
  subnet_group_name    = aws_elasticache_subnet_group.this[0].name
  security_group_ids   = [var.cache_security_group_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  automatic_failover_enabled = false
  multi_az_enabled           = false

  tags = {
    Name = "${var.name}-cache"
  }
}
