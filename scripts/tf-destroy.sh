#!/usr/bin/env bash
# Show what terraform/envs/example would destroy in a real AWS account,
# without destroying it. Extra arguments are passed straight through to
# terraform plan, e.g. ./scripts/tf-destroy.sh -var enable_nat_gateway=true
set -euo pipefail

cd "$(dirname "$0")/../terraform/envs/example"

if [ ! -f terraform.tfvars ]; then
  echo "terraform.tfvars not found, nothing to plan a destroy against" >&2
  exit 1
fi

if grep -q "REPLACE_WITH_YOUR_STATE_BUCKET" backend.tf 2>/dev/null; then
  echo "backend.tf still has the placeholder bucket name, there is no state to destroy" >&2
  exit 1
fi

echo "this plans a full teardown of everything terraform/envs/example created"
echo "in a real AWS account: VPC, ALBs, any database or cache, and every"
echo "service's autoscaling group. Nothing is destroyed by this script."
echo

terraform init -input=false
terraform plan -destroy -input=false "$@"

echo
echo "nothing was destroyed, run terraform apply -destroy yourself from" \
  "terraform/envs/example if the plan looks right"
