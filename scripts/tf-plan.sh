#!/usr/bin/env bash
# Show what terraform/envs/example would change against a real AWS account,
# without applying it. Extra arguments are passed straight through to
# terraform plan, e.g. ./scripts/tf-plan.sh -var enable_nat_gateway=true
set -euo pipefail

cd "$(dirname "$0")/../terraform/envs/example"

if [ ! -f terraform.tfvars ]; then
  echo "terraform.tfvars not found, copy terraform.tfvars.example and edit it first" >&2
  exit 1
fi

if grep -q "REPLACE_WITH_YOUR_STATE_BUCKET" backend.tf 2>/dev/null; then
  echo "backend.tf still has the placeholder bucket name, run terraform/bootstrap first and fill it in" >&2
  exit 1
fi

echo "this plans against a real AWS account. ALBs, VPC endpoints, and any"
echo "database, cache, or NAT Gateway this config enables cost money per"
echo "hour, whether or not a service uses them. See the README cost table."
echo

terraform init -input=false
terraform plan -input=false "$@"

echo
echo "no changes were applied, run terraform apply yourself from" \
  "terraform/envs/example if the plan looks right"
