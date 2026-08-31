# Tasks

The daily workflow reads this file, takes the first unchecked items under
Backlog, does them, and opens a pull request.

Keep the backlog full. An empty backlog means no run happens, which is
correct. Add tasks faster than they get consumed.

Write tasks as outcomes, not instructions.

## Backlog

- [ ] Audit every resource in both templates for encryption at rest and in transit, enable it where supported and missing, and add a Security section to the README documenting each
- [ ] Add a database boolean to each service in services.yaml, defaulting to false, validated in generate.py, with no resources created yet
- [ ] Create templates/service-database.yaml: per-service encrypted PostgreSQL with credentials in Secrets Manager, a security group accepting 5432 only from that service's instances, and outputs for endpoint and secret ARN
- [ ] Wire per-service databases into generate.py so database true produces a nested database stack, passing endpoint and secret ARN into the service stack
- [ ] Extend generate.py to pass every enabled resource's connection details to the service as environment variables on the launch template, so applications never hardcode endpoints
- [ ] Add a cache boolean and templates/service-cache.yaml providing a single-node encrypted ElastiCache Valkey cluster, with the monthly cost in a comment so the opt-in is informed
- [ ] Write docs/adding-a-resource-type.md explaining how to add a new optional per-service resource end to end, using the cache implementation as the worked example
- [ ] Add a compute field to services.yaml accepting ec2 or ecs, defaulting to ec2, validated in generate.py with only the ec2 path implemented
- [ ] Create templates/service-ecs.yaml providing an ECS Fargate service behind the same shared ALB with task definition, service, and log group, selected when compute is ecs
- [ ] Add a Compliance notes section to the README mapping what the templates provide to common control requirements: encryption at rest, encryption in transit, least-privilege IAM, network segmentation, audit logging. State plainly this is a starting point and not a certification
- [ ] Add a validation step to deploy.sh that runs generate.py and aws cloudformation validate-template on every generated template before deploying, failing early with a readable message
- [ ] Add a --dry-run flag to deploy.sh that creates and describes a change set without executing it
- [ ] Extend tests/test_generate.py to cover the database, cache, and compute fields: defaults, invalid values, and that enabling a resource produces the expected nested stack
- [ ] Add CONTRIBUTING.md explaining the repo layout, how generate.py relates to the templates, and the project's scope boundaries



## Done

- [x] Rewrite the README opening so it is honest about status: state plainly that the templates have not been deployed end to end against a live AWS account, and remove wording implying verified production use
- [x] Add a quickstart to the top of the README showing the shortest path from clone to a running service: copy the example, change one name, run deploy.sh, curl the ALB
- [x] Restrict egress on InstanceSecurityGroup in shared.yaml: 443 to the VPC CIDR for interface endpoints, 5432 to the database security group, and 80 and 443 outbound only when EnableNatGateway is true. Remove the implicit allow-all
- [x] Add CloudWatch alarms per service for unhealthy host count and 5xx rate
- [x] Add a CloudWatch dashboard per service showing ALB 5xx count, target response time, and in-service ASG capacity
- [x] Add CodePipeline and CodeBuild to service.yaml gated behind the repo field, and document the CodeStar Connections manual handshake in the README
- [x] Add a Known limitations section to the README covering position-derived listener priorities, no blue/green, the single shared database credential, and manual ACM certificate issuance
- [x] Write unit tests for generate.py covering priority assignment, duplicate detection, and the 95-service guard
- [x] Add a repo field to services.yaml and validate it in generate.py, without wiring CodePipeline yet
- [x] Create scripts/deploy.sh that creates an artifact bucket if missing, deploys the shared stack, runs generate.py, packages nested templates to S3, and deploys the services stack
- [x] Create scripts/teardown.sh that deletes the services stack then the shared stack in order, empties and deletes the artifact bucket, and lists any remaining NAT Gateways, load balancers, and RDS instances
- [x] Create scripts/budget-alarm.sh that creates a monthly AWS Budget with actual alerts at 50, 80, and 100 percent plus a forecast alert
- [x] Write the README architecture section with the two-stack model, an ASCII diagram, and the reasoning behind nested stacks, one shared ALB, and VPC endpoints over NAT
- [x] Add a cost table to the README with per-component monthly estimates in ap-south-1 and a note that teardown.sh should run after every session
- [x] Add an autoscaling group and target-tracking CPU scaling policy to service.yaml, placed in the private subnets with ELB health checks and a rolling update policy
- [x] Add a conditional Route 53 alias record to service.yaml, skipped when HostedZoneId is empty
- [x] Create generate.py that reads services.yaml and emits build/services.generated.yaml, a parent stack with one AWS::CloudFormation::Stack per service
- [x] Add validation to generate.py: reject duplicate service names, reject invalid exposure values, and fail above 95 services per listener since the default ALB quota is 100 rules
- [x] Create services.example.yaml showing a minimal entry, a fully specified entry, and an internal service
- [x] Add an IAM role, instance profile, and launch template to service.yaml with IMDSv2 required, encrypted gp3 root volume, and user data installing nginx that returns 200 on the health check path
- [x] Add an encrypted PostgreSQL instance to shared.yaml behind a CreateDatabase parameter, with master credentials generated into Secrets Manager and a SecretTargetAttachment
- [x] Export everything downstream needs from shared.yaml: VPC id, subnet ids, instance security group, both listener ARNs, both ALB DNS names and canonical hosted zone ids, database endpoint, secret ARN
- [x] Create templates/service.yaml with a target group and a host-header listener rule that imports the correct listener based on an Exposure parameter of public or internal
- [x] Add the internet-facing and internal ALBs to shared.yaml with HTTP listeners whose default action is a 404 fixed response, plus an optional HTTPS listener gated on a CertificateArn parameter
- [x] Add security groups to shared.yaml: public ALB, internal ALB, instance, and database, chained so instances only accept traffic from the ALBs and the database only from instances
- [x] Create templates/shared.yaml with the network layer only: VPC across two AZs, two public and two private subnets, internet gateway, route tables, and outputs exporting the VPC and subnet IDs
- [x] Add gateway VPC endpoint for S3 and interface endpoints for ssm, ssmmessages, and ec2messages to shared.yaml, with an EnableNatGateway parameter defaulting to false and a conditional NAT Gateway
- [x] Rework the NAT Gateway in shared.yaml to one per AZ so private subnets egress within their own AZ, per the multi-AZ rule for opt-in resources in CLAUDE.md, and note the doubled cost in a comment
