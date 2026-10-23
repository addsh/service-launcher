# service-launcher

Declare your services in one YAML file. Get a production-shaped AWS environment
for all of them.

```yaml
sharedStackName: launcher-shared
domainName: example.internal

services:
  - name: orders-api
  - name: payments-api
    port: 8080
    minSize: 2
    maxSize: 6
  - name: reconciliation-worker
    exposure: internal
```

```bash
./scripts/deploy.sh
```

Three services, or fifty, from the same file. Each one gets a target group, a
host-based listener rule on a shared ALB, a launch template, an autoscaling
group with target-tracking CPU scaling, a scoped IAM role, and a Route 53
record. Shared across all of them: the VPC, two ALBs (one internet-facing, one
internal), and a PostgreSQL instance.

---

## Why this exists

The usual way a small platform team handles fifty microservices is fifty
copy-pasted CloudFormation stacks that have quietly drifted apart, or a
Terraform module nobody outside the team can safely run. This is the middle
ground: one input file, one deploy command, and no per-service infrastructure
knowledge required from application developers.

## Architecture

```
services.yaml
     |
     v
generate.py  ---->  build/services.generated.yaml   (parent: N nested stacks)
                              |
                              v
            +-----------------+-----------------+
            |                 |                 |
      service stack     service stack     service stack
       (orders-api)    (payments-api)      (recon-worker)
            |                 |                 |
            +--------+--------+--------+--------+
                     |                 |
              public ALB         internal ALB
                     |                 |
                     +--------+--------+
                              |
                    shared VPC + PostgreSQL
                       (shared.yaml)
```

Two stacks, deployed in order:

**`templates/shared.yaml`** is deployed once per environment. VPC across two
AZs, public and private subnets, an internet-facing ALB and an internal ALB,
security groups wired so instances accept traffic only from the ALBs and the
database accepts traffic only from instances, and an optional encrypted
PostgreSQL instance whose master credentials are generated into Secrets Manager
and never appear in a parameter or a repo. Everything downstream needs is
published as a cross-stack export.

**`templates/service.yaml`** is deployed once per service, as a nested stack.
It imports from the shared stack and adds only what is specific to that
service.

## Three design decisions worth explaining

### Nested stacks, not one big template

CloudFormation caps a stack at 500 resources and has no loop construct. Each
service needs about nine resources, so inlining fifty services would land near
450 with no headroom, and one bad service would roll back all fifty.

Generating a parent stack with one `AWS::CloudFormation::Stack` per service
moves the ceiling from roughly 55 services to roughly 500, and isolates
failures to the service that caused them. A single service can be updated
without touching its neighbours.

The cost is that listener rule priorities must be unique per listener and
CloudFormation cannot compute them, so `generate.py` assigns them by position
within the exposure group. Append to `services.yaml` rather than reordering it;
reordering churns priorities and forces rule replacement.

### One ALB, not one per service

An ALB is around 16 to 25 USD/month before LCU charges. Fifty of them is a
four-figure annual bill for load balancers alone. Sharing one ALB with
host-based routing makes the marginal cost of an additional service just its
EC2 capacity.

The constraint this buys is the default quota of 100 rules per listener.
`generate.py` fails at generate time above 95, rather than three minutes into a
deploy. Past that, deploy a second shared stack.

### VPC endpoints instead of a NAT Gateway by default

Instances in private subnets need to reach SSM and S3. A NAT Gateway does that
for about 32 USD/month plus data processing charges. Interface endpoints for
SSM and a gateway endpoint for S3 cover the same need at a fraction of the cost
for this traffic profile.

`EnableNatGateway` exists for workloads that genuinely need general internet
egress, and defaults to `false`. Turning on a NAT Gateway should be a decision
someone makes, not a default they inherit.

## Cost

Roughly, in `ap-south-1`, with defaults:

| Component | Monthly (USD) |
|---|---|
| Public ALB | ~18 |
| Internal ALB | ~18 |
| `db.t4g.micro` PostgreSQL, 20 GB gp3, single AZ | ~15 |
| 3 interface VPC endpoints | ~22 |
| `t3.micro` per service instance | ~8 each |
| NAT Gateway, if enabled | ~32 + data |

Set `CreateDatabase=false` and run a single service and it drops to about 45.
**Run `./scripts/teardown.sh` at the end of every session.** It deletes stacks
in dependency order and then lists any NAT Gateways, load balancers, or RDS
instances still running in the region, because those are what generate a
surprise bill.

## Getting started

```bash
# 1. Set a budget alert before anything else
./scripts/budget-alarm.sh you@example.com 30

# 2. Declare your services
cp services.example.yaml services.yaml
$EDITOR services.yaml

# 3. Deploy
export AWS_REGION=ap-south-1
./scripts/deploy.sh

# 4. Verify (no DNS needed)
curl -H 'Host: orders-api.example.internal' http://<alb-dns-name>/

# 5. Tear down
./scripts/teardown.sh
```

Instances boot with nginx serving a placeholder page and a `200` on the health
check path, so a fresh deploy is verifiable end to end before you have an
application to put on it. Replace the `UserData` block in
`templates/service.yaml` with your own bootstrap, or point `AmiId` at a baked
image.

## Requirements

AWS CLI v2, Python 3.9+, PyYAML, and credentials with permission to create VPC,
ELB, EC2, Auto Scaling, RDS, IAM, Route 53, and CloudFormation resources.

## Roadmap

- [ ] CodePipeline per service, driven by a `repo` field in `services.yaml`
- [ ] ECS Fargate as an alternative compute target
- [ ] EKS as a third compute target, services scheduled onto a shared cluster
- [ ] CloudWatch dashboard and alarms generated per service
- [ ] Web UI that writes `services.yaml`, so application teams never open the
      infrastructure repo
- [ ] CIS-hardened base AMI via EC2 Image Builder

## Known limitations

Honest list, not a wish list:

- Listener rule priorities are position-derived. Reordering `services.yaml` is
  a breaking change; appending is not.
- No blue/green. The ASG rolling update policy replaces one instance at a time
  with a five minute pause, which is safe but slow at scale.
- The shared database is a single instance with one master credential. Real
  multi-tenancy needs per-service databases and roles.
- HTTPS requires you to supply an existing ACM certificate ARN. Certificate
  issuance and DNS validation are not automated.
- Not yet tested above three services. The quota reasoning is sound; the
  behaviour at fifty is unverified.

## License

MIT
