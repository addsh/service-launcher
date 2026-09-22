# service-launcher, Terraform port

This is the same architecture as the CloudFormation version in `templates/`,
built with Terraform instead. Shared VPC, both ALBs, VPC endpoints, an
optional shared database, and one module invocation per service. The
CloudFormation version stays as it is; this is a separate implementation of
the same design, not a replacement, and `templates/` does not change while
this is being built.

Where CloudFormation reaches for nested stacks because it has no loop
construct and a 500-resource ceiling per stack, Terraform has neither
problem: `for_each` over a services map handles any number of services in
one state file. That removes the reason nested stacks exist here, so this
port has no equivalent split. It picks up a different problem instead: state
locking and drift, which CloudFormation does not have to think about because
AWS owns the state.

Work in progress, not deployed against a real account yet. CI runs `terraform
fmt`, `terraform validate`, and `terraform test` on every push; it never runs
`plan` or `apply` against AWS.

## Layout

- `terraform/modules/<name>/` - reusable modules: `network`, `security`,
  `alb`, `database`, `service`, and later `cache` and `ecs-service`.
- `terraform/envs/example/` - the root module a user copies and edits, wiring
  the modules together and holding the services map.
- `terraform/bootstrap/` - a one-time apply that creates the S3 bucket
  `envs/example` uses for remote state.

## Conventions

- Remote state lives in S3 with native S3 locking (`use_lockfile = true`),
  not a DynamoDB lock table, since that mechanism is deprecated for new
  configurations.
- Services are a map variable iterated with `for_each`, never `count`, so
  removing one service does not renumber or move the others.
- Security group rules are separate `aws_vpc_security_group_ingress_rule` and
  `aws_vpc_security_group_egress_rule` resources, never inline blocks, to
  avoid the dependency cycles inline cross-references between two groups
  would create.
- Variable `validation` blocks mirror what `generate.py` checks for the
  CloudFormation version: name format, exposure enum, compute enum, and the
  95-service-per-listener cap.
- Same cost and security defaults as the CloudFormation version: NAT Gateway
  off by default, database single-AZ `db.t4g.micro` by default, IMDSv2
  required, EBS and RDS storage encrypted, no `Resource: "*"` or unrestricted
  security group rule without a comment saying why.
