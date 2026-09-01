#!/usr/bin/env python3
"""Read services.yaml and emit build/services.generated.yaml.

The generated template is a parent stack containing one
AWS::CloudFormation::Stack per service, each pointing at templates/service.yaml.
scripts/deploy.sh runs `aws cloudformation package` against the output, which
rewrites the local TemplateURL paths into S3 URLs.
"""

import re
import sys
from pathlib import Path

import yaml

SERVICES_FILE = Path("services.yaml")
SERVICE_TEMPLATE = "../templates/service.yaml"
SERVICE_ECS_TEMPLATE = "../templates/service-ecs.yaml"
SERVICE_DATABASE_TEMPLATE = "../templates/service-database.yaml"
SERVICE_CACHE_TEMPLATE = "../templates/service-cache.yaml"
OUTPUT_FILE = Path("build/services.generated.yaml")

ALLOWED_EXPOSURES = {"public", "internal"}
ALLOWED_COMPUTE = {"ec2", "ecs"}

# GitHub owner/repo, the shape CodeStar Connections needs later. Validated now
# so a typo surfaces at generate time instead of when CodePipeline is wired up.
REPO_PATTERN = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")

# The default ALB quota is 100 rules per listener. 95 leaves headroom for the
# fixed default-action rule and a couple of manual rules an operator might add.
MAX_SERVICES_PER_LISTENER = 95


def logical_id(name, suffix="Stack"):
    # CloudFormation logical ids are alphanumeric only.
    parts = re.split(r"[^a-zA-Z0-9]+", name)
    return "".join(part.capitalize() for part in parts if part) + suffix


def build_database_stack(service, config):
    name = service["name"]
    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": SERVICE_DATABASE_TEMPLATE,
            "Parameters": {
                "SharedStackName": config["sharedStackName"],
                "ServiceName": name,
            },
        },
    }


def build_cache_stack(service, config):
    name = service["name"]
    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": SERVICE_CACHE_TEMPLATE,
            "Parameters": {
                "SharedStackName": config["sharedStackName"],
                "ServiceName": name,
            },
        },
    }


def build_stack(service, config, priority, database_id, cache_id):
    name = service["name"]
    exposure = service.get("exposure", "public")
    host_header = service.get("hostHeader", f"{name}.{config['domainName']}")
    repo = service.get("repo", "")
    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": SERVICE_TEMPLATE,
            "Parameters": {
                "SharedStackName": config["sharedStackName"],
                "ServiceName": name,
                "Port": service.get("port", 80),
                "HealthCheckPath": service.get("healthCheckPath", "/"),
                "HostHeader": host_header,
                "Exposure": exposure,
                "Priority": priority,
                "InstanceType": service.get("instanceType", "t3.micro"),
                "MinSize": service.get("minSize", 1),
                "MaxSize": service.get("maxSize", 3),
                "HostedZoneId": service.get("hostedZoneId", ""),
                "Repo": repo,
                "CodeStarConnectionArn": config.get("codeStarConnectionArn", "") if repo else "",
                "BranchName": service.get("branch", "main"),
                "DatabaseEndpoint": (
                    {"Fn::GetAtt": f"{database_id}.Outputs.Endpoint"} if database_id else ""
                ),
                "DatabaseSecretArn": (
                    {"Fn::GetAtt": f"{database_id}.Outputs.SecretArn"} if database_id else ""
                ),
                "CacheEndpoint": (
                    {"Fn::GetAtt": f"{cache_id}.Outputs.Endpoint"} if cache_id else ""
                ),
                "CachePort": (
                    {"Fn::GetAtt": f"{cache_id}.Outputs.Port"} if cache_id else ""
                ),
            },
        },
    }


def build_ecs_stack(service, config, priority, database_id, cache_id):
    # No InstanceType/ImageId/RootVolumeSize: those are ec2 launch template
    # concerns. No Repo/CodeStarConnectionArn/BranchName: validate() rejects
    # repo with compute=ecs, since a working pipeline for it needs an ECR
    # push and a task definition update, which service-ecs.yaml doesn't do.
    name = service["name"]
    exposure = service.get("exposure", "public")
    host_header = service.get("hostHeader", f"{name}.{config['domainName']}")
    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": SERVICE_ECS_TEMPLATE,
            "Parameters": {
                "SharedStackName": config["sharedStackName"],
                "ServiceName": name,
                "Port": service.get("port", 80),
                "HealthCheckPath": service.get("healthCheckPath", "/"),
                "HostHeader": host_header,
                "Exposure": exposure,
                "Priority": priority,
                "MinSize": service.get("minSize", 1),
                "MaxSize": service.get("maxSize", 3),
                "HostedZoneId": service.get("hostedZoneId", ""),
                "DatabaseEndpoint": (
                    {"Fn::GetAtt": f"{database_id}.Outputs.Endpoint"} if database_id else ""
                ),
                "DatabaseSecretArn": (
                    {"Fn::GetAtt": f"{database_id}.Outputs.SecretArn"} if database_id else ""
                ),
                "CacheEndpoint": (
                    {"Fn::GetAtt": f"{cache_id}.Outputs.Endpoint"} if cache_id else ""
                ),
                "CachePort": (
                    {"Fn::GetAtt": f"{cache_id}.Outputs.Port"} if cache_id else ""
                ),
            },
        },
    }


def validate(config):
    names = set()
    counts = {"public": 0, "internal": 0}
    for service in config["services"]:
        name = service["name"]
        if name in names:
            sys.exit(f"duplicate service name: {name}")
        names.add(name)

        exposure = service.get("exposure", "public")
        if exposure not in ALLOWED_EXPOSURES:
            sys.exit(f"{name}: exposure must be one of {sorted(ALLOWED_EXPOSURES)}, got {exposure!r}")
        counts[exposure] += 1

        database = service.get("database", False)
        if not isinstance(database, bool):
            sys.exit(f"{name}: database must be true or false, got {database!r}")

        cache = service.get("cache", False)
        if not isinstance(cache, bool):
            sys.exit(f"{name}: cache must be true or false, got {cache!r}")

        compute = service.get("compute", "ec2")
        if compute not in ALLOWED_COMPUTE:
            sys.exit(f"{name}: compute must be one of {sorted(ALLOWED_COMPUTE)}, got {compute!r}")

        repo = service.get("repo")
        if repo is not None:
            if not REPO_PATTERN.match(repo):
                sys.exit(f"{name}: repo must be of the form owner/repo, got {repo!r}")
            if compute == "ecs":
                sys.exit(
                    f"{name}: repo is not supported with compute=ecs yet, a working "
                    "pipeline needs an ECR push and a task definition update"
                )
            if not config.get("codeStarConnectionArn"):
                sys.exit(
                    f"{name}: repo is set but codeStarConnectionArn is missing from "
                    "services.yaml, CodePipeline needs it to authorize GitHub access"
                )

    for exposure, count in counts.items():
        if count > MAX_SERVICES_PER_LISTENER:
            sys.exit(
                f"{count} {exposure} services exceeds the {MAX_SERVICES_PER_LISTENER} "
                "per-listener limit"
            )


def generate(config):
    resources = {}
    # Priorities are assigned per listener, not globally: a public and an
    # internal service can legally share the same priority number since they
    # sit on different listeners, and generate.py is the only place that can
    # compute this since CloudFormation cannot.
    next_priority = {"public": 1, "internal": 1}
    for service in config["services"]:
        name = service["name"]
        exposure = service.get("exposure", "public")
        priority = next_priority[exposure]
        next_priority[exposure] += 1

        database_id = None
        if service.get("database", False):
            database_id = logical_id(name, "DatabaseStack")
            resources[database_id] = build_database_stack(service, config)

        cache_id = None
        if service.get("cache", False):
            cache_id = logical_id(name, "CacheStack")
            resources[cache_id] = build_cache_stack(service, config)

        if service.get("compute", "ec2") == "ecs":
            resources[logical_id(name)] = build_ecs_stack(service, config, priority, database_id, cache_id)
        else:
            resources[logical_id(name)] = build_stack(service, config, priority, database_id, cache_id)
    return {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "Generated by generate.py from services.yaml. Do not edit by hand.",
        "Resources": resources,
    }


def main():
    if not SERVICES_FILE.exists():
        sys.exit(f"{SERVICES_FILE} not found")
    with SERVICES_FILE.open() as f:
        config = yaml.safe_load(f)

    validate(config)
    template = generate(config)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_FILE.open("w") as f:
        yaml.safe_dump(template, f, sort_keys=False)
    print(f"wrote {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
