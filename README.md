# service-launcher

Declare your services in one YAML file. Get a production-shaped AWS
environment for all of them.

Work in progress. See TASKS.md for what is being built.

## Goal

```yaml
sharedStackName: launcher-shared
domainName: example.internal

services:
  - name: orders-api
  - name: payments-api
    port: 8080
    minSize: 2
  - name: reconciliation-worker
    exposure: internal
```

```bash
./scripts/deploy.sh
```

Three services, or fifty, from the same file. Each gets a target group, a
host-based listener rule on a shared ALB, an autoscaling group, and a DNS
record. Shared across all of them: the VPC, two ALBs, and a PostgreSQL
instance.

## Architecture

Two stacks. templates/shared.yaml deploys once per environment: the VPC,
two ALBs, VPC endpoints, and an optional PostgreSQL instance. templates/
service.yaml deploys once per service, as a nested stack under a generated
parent, and holds only what is specific to that service: a target group, a
listener rule, an IAM role, a launch template, an autoscaling group, and an
optional DNS record.

```
                     Internet
                        |
                        v
              +-------------+     +-------------+
              | public ALB  |     |internal ALB |    shared.yaml
              +-------------+     +-------------+
                    |                    |
             host-header rule     host-header rule
              per public service   per internal service
                    v                    v
              +-------------+     +-------------+
              | service ASG | ... | service ASG |     service.yaml
              | (private     |    | (private     |    (nested stack,
              |  subnet)     |    |  subnet)     |     one per service)
              +-------------+     +-------------+
                     \                   /
                      v                 v
                 +-----------------------+
                 |  PostgreSQL, optional  |    shared.yaml
                 |  (CreateDatabase=true) |
                 +-----------------------+

services.yaml -> generate.py -> build/services.generated.yaml
                                 (parent stack, one AWS::CloudFormation::Stack
                                  per service, each pointing at service.yaml)
```

Nested stacks, not one flat stack. CloudFormation caps a stack at 500
resources and has no loop construct. Each service needs roughly nine
resources, so fifty services inlined would land near 450 with no headroom,
and one bad service would roll back all fifty. Nested stacks move the
ceiling to roughly 500 services and isolate a failing service from the
others. The cost is that ALB listener rule priorities must be unique per
listener and CloudFormation cannot compute them, so generate.py assigns them
by position.

Two shared ALBs, not one per service. An ALB bills whether or not it is
carrying traffic, so fifty ALBs for fifty services would be the single
largest line item in the whole setup. One public and one internal ALB, with
services distinguished by a host-header listener rule, means the ALB cost
stays flat as services are added. The tradeoff is the 100-rule-per-listener
quota, which is why generate.py caps a listener at 95 services.

VPC endpoints, not a NAT Gateway, by default. Instances in the private
subnets need to reach SSM (for Session Manager access) and S3 (for the
CloudFormation package artifacts). A NAT Gateway would cover that plus
arbitrary internet egress, but it bills per hour whether used or not, on top
of a per-AZ EIP. Gateway and interface VPC endpoints cover the same two
destinations for less, and don't require a public subnet to route through.
NAT Gateway is still available behind the EnableNatGateway parameter for a
service that genuinely needs to reach the open internet.

## License

MIT
