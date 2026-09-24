# Importing existing resources into terraform/

This is for adopting a resource that already exists in AWS, hand-created or
left over from something else, into the terraform/ layout instead of letting
Terraform create a duplicate. It uses import blocks, not `terraform import`,
since import blocks can be planned before anything is applied.

## The general workflow

1. Find the resource's id: an instance id, a security group id, a VPC id,
   whatever the resource type uses. The AWS console or `aws` CLI both work.
2. Write the `resource` block for it in the right module or root module
   file, matching its live configuration as closely as you can. It does not
   need to be perfect yet; the plan in step 4 will show what is still wrong.
3. Add an `import` block naming that resource and its id. Put import blocks
   in their own file, `import.tf`, next to the resource they target, so they
   are easy to find and delete once the import is done.
4. Run `terraform plan`. Read it carefully. An import produces a plan like
   any other change: resources with matching configuration show as imported
   with no other changes, and anything mismatched shows as a diff against
   what you wrote. Fix the resource block, not the live resource, until the
   plan for that resource is either a clean import or a change you intend.
5. Run `terraform apply`. This records the resource in state; it does not
   recreate or modify it unless the plan showed a diff you accepted.
6. Delete the `import` block. It has no effect after the resource is in
   state, and leaving it in only adds noise to future plans.

Steps 4 and 5 are the only ones that touch a real account. Nothing about
writing the resource and import blocks does.

## A worked example: adopting a hand-created VPC

Say a VPC, its subnets, and its internet gateway already exist, created by
hand before this repo existed, and the goal is to bring them under
`modules/network` instead of building a second VPC next to them.

```hcl
# terraform/envs/example/import.tf

import {
  to = module.network.aws_vpc.this
  id = "vpc-0123456789abcdef0"
}

import {
  to = module.network.aws_internet_gateway.this
  id = "igw-0123456789abcdef0"
}
```

`modules/network` uses `for_each` for its subnets, keyed by availability
zone, so importing a subnet needs the same key the module would compute
itself:

```hcl
import {
  to = module.network.aws_subnet.public["ap-south-1a"]
  id = "subnet-0123456789abcdef0"
}
```

Run `terraform plan` before writing every subnet's import block. The plan
for `aws_vpc.this` and `aws_internet_gateway.this` will show mismatches for
anything `modules/network` sets that the hand-created resources do not have,
most commonly the `Name` tag. Add the tag to the real resource, or accept
the diff and let Terraform apply it, whichever is true: this repo's
convention is that Terraform's configuration wins, since it is what every
future change goes through.

## Importing a resource behind for_each

Anything created per-service, an `aws_db_instance` in
`module.service_database["orders-api"]` or an `aws_autoscaling_group` in
`module.service["orders-api"]`, is addressed the same way any other
`for_each` module instance is: the module call name, the service's key in
the `services` map, then the resource inside that module.

```hcl
import {
  to = module.service_database["orders-api"].aws_db_instance.this
  id = "orders-api-db"
}
```

The id format is resource-type-specific. `aws_db_instance` takes the DB
instance identifier; most other resources take their ARN or their AWS-
assigned id. The AWS provider docs for each resource type list which one it
expects, under an "Import" heading.

## What this does not cover

Import blocks bring a resource into state; they do not reconcile Terraform's
configuration with everything about the live resource automatically. A
resource with many settings, a security group with a long list of hand-added
rules, or an RDS instance with a custom parameter group someone tuned by
hand, still needs its configuration written out property by property. Plan,
read the diff, and decide for each mismatch whether the real resource should
change or the configuration should, before applying.

Nothing in this repo automates any of these steps. There is no
`terraform-import.sh`; running `terraform plan` and `terraform apply` by
hand, once, is the whole point, since an import is a one-time reconciliation
against a specific real account and should not be scripted into something
that could run against the wrong one.
