# Contributing

This is a personal-account CloudFormation project, not a library with a
stable public API. The rules below keep changes small and reviewable. See
CLAUDE.md for the full set of project rules, including CloudFormation
conventions and writing style; this file is the shorter version aimed at a
human contributor picking up a task.

## Layout

- `services.yaml`: the user's service declarations. Gitignored, holds
  personal config. `services.example.yaml` is the checked-in reference.
- `generate.py`: reads `services.yaml`, writes `build/services.generated.yaml`.
- `templates/shared.yaml`: the VPC, both ALBs, VPC endpoints, and the
  optional shared PostgreSQL instance. Deployed once per environment.
- `templates/service.yaml`, `service-ecs.yaml`, `service-database.yaml`,
  `service-cache.yaml`: nested stacks, one per service per resource it opts
  into. `service.yaml` is the ec2 compute path, `service-ecs.yaml` is the
  Fargate path, the other two are the per-service database and cache.
- `scripts/deploy.sh`, `teardown.sh`, `budget-alarm.sh`: the operational
  scripts, no dependencies beyond the AWS CLI and Python.
- `docs/adding-a-resource-type.md`: the worked example for adding a new
  opt-in per-service resource, using cache as the reference.
- `tests/test_generate.py`: unit tests for `generate.py`'s validation and
  template generation. No AWS access needed to run them.

## How generate.py relates to the templates

`generate.py` never writes a CloudFormation resource itself. It reads each
service entry, decides which nested templates that service needs based on
its `compute`, `database`, `repo`, and (once wired) `cache` fields, and
emits one `AWS::CloudFormation::Stack` resource per template into
`build/services.generated.yaml`. That file is a parent stack; `deploy.sh`
packages it and the nested templates it points at, then deploys the parent.
All the actual resources live in `templates/*.yaml`. If you are adding a
field to `services.yaml`, the field has to be read in `generate.py` and
turned into a parameter passed to the right nested template; it does
nothing on its own.

## Scope

One task per pull request. Do not fix unrelated things you notice along the
way, even small ones; open a separate PR for those.

No dependencies beyond the Python standard library and PyYAML. If a task
seems to need one, that is a sign that the task should be scoped down.

Do not reorganize directories as part of an unrelated change.

If a change would touch more than three files, open the PR anyway and say
in the body that the task needs splitting.

## What you cannot touch

Pull requests touching `.github/workflows/` will not merge here: the bot
token that runs this repo's automation has no `workflows` permission.
Skip any task that requires editing a workflow file.

## Before opening a PR

Run the tests:

```bash
python3 -m unittest discover tests
```

If your change touches a template, check it parses:

```bash
python3 generate.py
aws cloudformation validate-template --template-body file://templates/service.yaml
```

`aws cloudformation validate-template` needs AWS credentials; it checks
template syntax and parameters, not whether the resources it describes will
actually create successfully.
