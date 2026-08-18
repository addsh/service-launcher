# Project rules

Read this before making any change.

## What this repo is

A CloudFormation-based service launcher. A user declares services in
services.yaml, runs ./scripts/deploy.sh, and gets a shared VPC, shared public
and internal ALBs, a PostgreSQL instance, and one nested stack per service.

Target shape once built:

- templates/shared.yaml: VPC, subnets, VPC endpoints, both ALBs, security
  groups, RDS PostgreSQL. Deployed once per environment. Publishes cross-stack
  exports.
- templates/service.yaml: target group, listener rule, IAM role, launch
  template, ASG, scaling policy, Route 53 record. Deployed once per service as
  a nested stack.
- generate.py: reads services.yaml, emits a parent stack containing one
  AWS::CloudFormation::Stack per service.
- scripts/deploy.sh, scripts/teardown.sh, scripts/budget-alarm.sh

## Why nested stacks

CloudFormation caps a stack at 500 resources and has no loop construct. Each
service needs roughly nine resources, so inlining fifty services would land
near 450 with no headroom, and one bad service would roll back all fifty.
Nested stacks move the ceiling to roughly 500 services and isolate failures.

The cost is that ALB listener rule priorities must be unique per listener and
CloudFormation cannot compute them, so generate.py assigns them by position.

## Scope discipline

- One task per pull request. Do not fix unrelated things you notice.
- No dependencies beyond the standard library and PyYAML.
- Do not reorganise directories.
- If a change would touch more than three files, open the PR anyway and note
  that the task needs splitting.

## Cost discipline

This gets deployed to a personal AWS account. Every resource that costs money
gets a line in the README cost table. Default to the cheap option and make the
expensive one opt-in. NAT Gateway defaults to off; VPC endpoints cover SSM and
S3 instead. Database defaults to db.t4g.micro, single AZ.

## CloudFormation conventions

- YAML with short-form intrinsics (!Ref, !Sub, !GetAtt).
- Cross-stack references use Fn::ImportValue against exports named
  ${SharedStackName}-<Thing>.
- IAM policies name explicit resource ARNs. No Resource: "*" unless the action
  genuinely requires it, and then leave a comment saying why.
- IMDSv2 required on all launch templates. EBS encrypted.
- Database credentials generated into Secrets Manager, never a parameter.

## Writing style

No em dashes anywhere: code comments, docs, commit messages, PR bodies.
No emoji.

Comments explain why, not what. "# increment counter" is noise. "# ALB
listener rule priorities must be unique per listener" is useful.

README prose is plain and specific. State limitations rather than hiding them.
A "Known limitations" section that is honest reads better than one that is
absent.

## Commit and PR wording

Write like a tired engineer finishing a task, not like a changelog.

Never use these words: comprehensive, robust, seamless, leverage, enhance,
streamline, ensure, facilitate, delve, elevate, unlock, empower, cutting-edge,
best-in-class, dive into.

Never title a PR with a gerund phrase like "Implementing a comprehensive
solution for observability". Write "add per-service CloudWatch alarms".

Never write a PR body as three parallel bullets. That structure is the
clearest tell. Write two or three plain sentences.

Lowercase commit subjects, no trailing period, under 60 characters.

Examples:
  bad:  feat: implement comprehensive CloudWatch observability enhancements
  good: add 5xx and unhealthy host alarms per service

  bad:  refactor: streamline the deployment orchestration workflow
  good: move nested template packaging into deploy.sh

If something is half done or you are unsure, say so plainly in the PR body.
"Not sure the health check grace period is long enough, worth checking on a
real deploy" is exactly the right register.

## What not to do

- Never push directly to main.
- Never commit services.yaml. It is gitignored, it holds user config.
- Never commit credentials, account IDs, or ARNs from a real account.
- Never generate commits for the sake of activity. If the backlog is empty,
  do nothing.

## Making design decisions

Decide and implement. Do not defer a design question to the reviewer. If you
find yourself writing "not sure whether", pick the option these principles
point to, implement it, and record the reasoning as a comment in the template
plus one sentence in the PR body.

Order of precedence when principles conflict:

1. Correctness and security. Never trade these for cost or simplicity.
2. Cost, for anything that is on by default.
3. Availability, for anything that is opt-in.
4. Simplicity.

Applied to the recurring cases in this repo:

- Optional feature that costs money: default it off, make the on path
  production-shaped rather than minimal. Someone who opts in wants it to work
  properly, and by opting in has accepted the cost.
- Single-AZ versus multi-AZ for an opt-in resource: multi-AZ. A user who
  enables NAT egress or a database is running something real. Cross-AZ data
  charges and a single point of failure are worse than the second resource.
- Single-AZ versus multi-AZ for an on-by-default resource: single AZ, with a
  parameter to raise it.
- Security group scope: always the narrowest that works. Never widen a rule to
  avoid writing a second rule.
- IAM: explicit resource ARNs. If a wildcard is genuinely required, leave a
  comment naming the API that requires it.
- Parameter defaults: the cheap, safe option. Expensive or risky settings are
  opt-in.
- When a decision has a real tradeoff, put the reasoning in a comment above
  the resource, not only in the PR body. The PR gets buried; the template is
  read.
