#!/usr/bin/env python3
"""Read services.yaml and emit a parent stack, one nested stack per service."""

import argparse
import os
import re
import sys

import yaml

# Maps a services.yaml field to the service.yaml CloudFormation parameter it
# feeds. ServiceName, HostHeader, and Priority are handled separately because
# they are either required or computed rather than passed through as-is.
OPTIONAL_FIELDS = {
    "port": "Port",
    "health_check_path": "HealthCheckPath",
    "exposure": "Exposure",
    "instance_type": "InstanceType",
    "image_id": "ImageId",
    "root_volume_size": "RootVolumeSize",
    "min_capacity": "MinCapacity",
    "max_capacity": "MaxCapacity",
    "desired_capacity": "DesiredCapacity",
    "target_cpu_utilization": "TargetCpuUtilization",
    "hosted_zone_id": "HostedZoneId",
}

FIRST_PRIORITY = 1

# The default ALB quota is 100 rules per listener, and the account can raise
# it, but generate.py has no way to know the actual quota, so it fails early
# at a conservative number rather than let a deploy fail partway through.
MAX_SERVICES_PER_LISTENER = 95


class Ref:
    """Marker for a CloudFormation !Ref, so the dumper can emit short form."""

    def __init__(self, name):
        self.name = name


class CfnDumper(yaml.SafeDumper):
    pass


CfnDumper.add_representer(Ref, lambda dumper, data: dumper.represent_scalar("!Ref", data.name))


def logical_id(service_name):
    # AWS::CloudFormation::Stack logical ids must be alphanumeric. The
    # "Service" prefix keeps the id valid even if the name starts with a
    # digit and keeps generated ids readable in the console.
    parts = re.split(r"[^a-zA-Z0-9]+", service_name)
    return "Service" + "".join(part.capitalize() for part in parts if part)


def validate_services(services):
    seen_names = set()
    counts = {"public": 0, "internal": 0}
    for service in services:
        name = service.get("name")
        if not name:
            raise ValueError("a service is missing the required 'name' field")
        if name in seen_names:
            raise ValueError(f"duplicate service name '{name}'")
        seen_names.add(name)

        exposure = service.get("exposure", "public")
        if exposure not in counts:
            raise ValueError(
                f"service '{name}' has exposure '{exposure}', expected 'public' or 'internal'"
            )
        counts[exposure] += 1

    for exposure, count in counts.items():
        if count > MAX_SERVICES_PER_LISTENER:
            raise ValueError(
                f"{count} {exposure} services exceeds the {MAX_SERVICES_PER_LISTENER} "
                "per-listener guard (the default ALB quota is 100 rules per listener)"
            )


def assign_priorities(services):
    # Listener rule priorities must be unique per listener and CloudFormation
    # cannot compute them, so they are assigned by position within each
    # exposure, in the order services appear in services.yaml. Assumes
    # validate_services has already run, so every exposure is known-good.
    counters = {"public": FIRST_PRIORITY, "internal": FIRST_PRIORITY}
    priorities = []
    for service in services:
        exposure = service.get("exposure", "public")
        priorities.append(counters[exposure])
        counters[exposure] += 1
    return priorities


def build_service_resource(service, priority, template_url):
    parameters = {
        "SharedStackName": Ref("SharedStackName"),
        "ServiceName": service["name"],
        "HostHeader": service["host_header"],
        "Priority": priority,
    }
    for yaml_key, cfn_key in OPTIONAL_FIELDS.items():
        if yaml_key in service:
            parameters[cfn_key] = service[yaml_key]

    return {
        "Type": "AWS::CloudFormation::Stack",
        "Properties": {
            "TemplateURL": template_url,
            "Parameters": parameters,
        },
    }


def build_template(services, template_url):
    if not services:
        raise ValueError("services.yaml has no services, nothing to generate")

    validate_services(services)
    priorities = assign_priorities(services)

    resources = {}
    for service, priority in zip(services, priorities):
        resources[logical_id(service["name"])] = build_service_resource(
            service, priority, template_url
        )

    return {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": (
            "Parent stack generated from services.yaml. One "
            "AWS::CloudFormation::Stack per service. Do not edit by hand."
        ),
        "Parameters": {
            "SharedStackName": {
                "Type": "String",
                "Description": "Name of the deployed shared.yaml stack, passed through to every service.",
            }
        },
        "Resources": resources,
    }


def relative_template_url(output_path):
    repo_root = os.path.dirname(os.path.abspath(__file__))
    service_template = os.path.join(repo_root, "templates", "service.yaml")
    output_dir = os.path.dirname(os.path.abspath(output_path)) or "."
    return os.path.relpath(service_template, output_dir)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--services-file", default="services.yaml")
    parser.add_argument("--output", default=os.path.join("build", "services.generated.yaml"))
    args = parser.parse_args()

    with open(args.services_file) as f:
        config = yaml.safe_load(f) or {}

    services = config.get("services", [])
    template = build_template(services, relative_template_url(args.output))

    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    with open(args.output, "w") as f:
        f.write("# generated by generate.py from services.yaml, do not edit by hand\n")
        yaml.dump(template, f, Dumper=CfnDumper, sort_keys=False, default_flow_style=False)

    print(f"wrote {args.output} with {len(services)} service(s)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, FileNotFoundError) as e:
        print(f"generate.py: {e}", file=sys.stderr)
        sys.exit(1)
