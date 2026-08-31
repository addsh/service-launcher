# service-launcher

Declare your services in one YAML file. Get a production-shaped AWS
environment for all of them.

Work in progress. The templates have not been deployed end to end against a
live AWS account. They are written to work and reviewed for correctness, but
nothing here has been verified against real CloudFormation runs yet. See
TASKS.md for what is being built.

## Quickstart

```bash
cp services.example.yaml services.yaml
# edit services.yaml: change the first service's name to something of yours
./scripts/deploy.sh
```

That deploys the shared stack (VPC, both ALBs, VPC endpoints) and then a
nested stack per service. The shared stack takes the longest, mostly the
interface VPC endpoints.

Routing is host-based, so curl needs the Host header a service was assigned.
The default is `<service-name>.<domainName>` from services.yaml.

```bash
ALB_DNS=$(aws cloudformation describe-stacks --stack-name launcher-shared \
  --query "Stacks[0].Outputs[?OutputKey=='PublicAlbDnsName'].OutputValue" \
  --output text)
curl -H "Host: orders-api.example.internal" "http://$ALB_DNS/"
```

Run scripts/teardown.sh when done. See Cost below for why that matters.

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

## CodePipeline and CodeBuild

Setting `repo` on a service (and `codeStarConnectionArn` once, at the top of
services.yaml) creates a CodePipeline with a Source stage and a Build stage:
CodeBuild runs on every push to `branch`, using a buildspec.yml the service
repo provides. There is no deploy stage. The build artifact lands in an S3
bucket and stops there; wiring it into the autoscaling group is unbuilt, see
Known limitations.

The CodeStar Connection itself cannot be created by CloudFormation or the
CLI. It requires a one-time handshake through the AWS console:

1. In the console, go to Developer Tools > Settings > Connections > Create
   connection, choose GitHub.
2. Follow the prompt to install the AWS Connector for GitHub app on the
   organization that owns the repos you want built, granting it access to
   those repos.
3. Complete the connection. Its status moves from Pending to Available only
   after the GitHub-side authorization finishes in a browser tab.
4. Copy the connection ARN into `codeStarConnectionArn` in services.yaml.

Do this once per AWS account; every service's pipeline can reuse the same
connection as long as the GitHub app has access to that service's repo.

## Cost

Rough monthly estimates in ap-south-1, list pricing as of writing. Actual
cost depends on traffic and data transfer; check the AWS Pricing Calculator
for current numbers before relying on these.

| Component | Estimate | On by default |
| --- | --- | --- |
| Public ALB | $18-20 base, plus LCU usage | yes |
| Internal ALB | $18-20 base, plus LCU usage | yes |
| Interface VPC endpoints (ssm, ssmmessages, ec2messages, 2 AZs each) | $43 | yes |
| S3 gateway endpoint | free | yes |
| Artifact S3 bucket | under $1 | yes |
| t3.micro instance, per running service instance | $8-9 | yes, one per service by default |
| gp3 root volume, 8 GiB, per instance | under $1 | yes |
| NAT Gateway, one per AZ | $65-70 combined, plus data processing | no, EnableNatGateway |
| PostgreSQL db.t4g.micro, Multi-AZ, 20 GiB gp3 | $28-30 | no, CreateDatabase |
| Secrets Manager secret | $0.40 | no, only with CreateDatabase |
| CodePipeline, per service | $1 after the first free pipeline per month | no, only with repo set |
| CodeBuild, BUILD_GENERAL1_SMALL | $0.005 per build minute | no, only with repo set |
| Pipeline artifact S3 bucket, per service | under $1 | no, only with repo set |
| CloudWatch dashboard, per service | $3 after the first three free dashboards per account | yes |
| CloudWatch alarms, 2 per service | $0.20 after the first ten free alarms per account | yes |

Nothing in this table tears itself down. Run scripts/teardown.sh at the end
of every session; a personal account left running a shared ALB, three
interface endpoints, and a couple of EC2 instances is a few dollars a day
that adds up if forgotten.

## Known limitations

Listener rule priorities are assigned by position in services.yaml, not by a
stable key. Reordering the services list, or deleting one from the middle,
shifts every priority after it and updates every listener rule below the
change on the next deploy. This is harmless (the rules still route the same
host headers) but it means a deploy diff can touch far more of the stack
than the actual edit.

No blue/green or canary deploys. A service update replaces instances through
the autoscaling group's rolling update policy, one batch at a time, gated
only by the ELB health check. There is no way to shift a fraction of traffic
to a new version and watch it before committing the rest.

One database credential, shared by every service. CreateDatabase produces a
single master secret in Secrets Manager; there is no per-service database
user or password. A service with a compromised credential has the same
database access as every other service.

ACM certificates are issued manually. The optional HTTPS listener takes a
CertificateArn parameter, but nothing in this repo requests or validates the
certificate. Get one issued and validated in ACM first, in the same region
as the shared stack, then pass its ARN in.

CodePipeline builds but does not deploy. Setting repo gets a service built on
every push, but the build output is not deployed anywhere: there is no
CodeDeploy stage or instance refresh triggered from the pipeline. Getting a
new build onto the autoscaling group is still a manual step.

Alarms are silent by default. Each service gets an unhealthy host alarm and a
5xx alarm, but AlarmSnsTopicArn is empty unless set, so nothing actually
notifies anyone until you point it at a topic. The 5xx alarm is a raw count
per period, not a percentage of traffic, since computing a real rate needs a
metric math expression and a decision about what happens at zero traffic.

## License

MIT
