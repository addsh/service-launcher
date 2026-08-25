# Tasks

The daily workflow reads this file, takes the first unchecked items under
Backlog, does them, and opens a pull request.

Keep the backlog full. An empty backlog means no run happens, which is
correct. Add tasks faster than they get consumed.

Write tasks as outcomes, not instructions.

## Backlog

- [ ] Add a Known limitations section to the README covering position-derived listener priorities, no blue/green, the single shared database credential, and manual ACM certificate issuance
- [ ] Add a pull request workflow running cfn-lint on templates and a syntax check on generate.py
- [ ] Write unit tests for generate.py covering priority assignment, duplicate detection, and the 95-service guard
- [ ] Add a repo field to services.yaml and validate it in generate.py, without wiring CodePipeline yet
- [ ] Add CodePipeline and CodeBuild to service.yaml gated behind the repo field, and document the CodeStar Connections manual handshake in the README
- [ ] Add a CloudWatch dashboard per service showing ALB 5xx count, target response time, and in-service ASG capacity
- [ ] Add CloudWatch alarms per service for unhealthy host count and 5xx rate

## Done

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
