#!/usr/bin/env bash
# Tear down everything scripts/deploy.sh created: the services stack, the
# shared stack, and the artifact bucket. Finishes by listing any NAT
# Gateways, load balancers, and RDS instances still in the account, since
# those are the resources that keep billing if a stack delete gets stuck.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f services.yaml ]; then
  echo "services.yaml not found, nothing to tear down" >&2
  exit 1
fi

SHARED_STACK_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('services.yaml'))['sharedStackName'])")
SERVICES_STACK_NAME="${SHARED_STACK_NAME}-services"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
  echo "no AWS region configured, run aws configure or set AWS_DEFAULT_REGION" >&2
  exit 1
fi

ARTIFACT_BUCKET="service-launcher-artifacts-${ACCOUNT_ID}-${REGION}"

delete_stack() {
  local stack_name="$1"
  if aws cloudformation describe-stacks --stack-name "$stack_name" >/dev/null 2>&1; then
    echo "deleting stack ${stack_name}"
    aws cloudformation delete-stack --stack-name "$stack_name"
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name"
  else
    echo "stack ${stack_name} does not exist, skipping"
  fi
}

# Services stack first: its nested stacks import the shared stack's exports,
# and CloudFormation refuses to delete a stack whose exports are still
# imported elsewhere.
delete_stack "$SERVICES_STACK_NAME"
delete_stack "$SHARED_STACK_NAME"

if aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" 2>/dev/null; then
  echo "emptying and deleting artifact bucket ${ARTIFACT_BUCKET}"
  aws s3 rm "s3://${ARTIFACT_BUCKET}" --recursive
  aws s3api delete-bucket --bucket "$ARTIFACT_BUCKET"
else
  echo "artifact bucket ${ARTIFACT_BUCKET} does not exist, skipping"
fi

echo
echo "checking for leftover NAT Gateways, load balancers, and RDS instances in ${REGION}"

NAT_GATEWAYS=$(aws ec2 describe-nat-gateways \
  --filter Name=state,Values=available,pending \
  --query 'NatGateways[].NatGatewayId' --output text)
if [ -n "$NAT_GATEWAYS" ]; then
  echo "NAT Gateways still running: ${NAT_GATEWAYS}"
else
  echo "no NAT Gateways found"
fi

LOAD_BALANCERS=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].LoadBalancerName' --output text)
if [ -n "$LOAD_BALANCERS" ]; then
  echo "load balancers still running: ${LOAD_BALANCERS}"
else
  echo "no load balancers found"
fi

DB_INSTANCES=$(aws rds describe-db-instances \
  --query 'DBInstances[].DBInstanceIdentifier' --output text)
if [ -n "$DB_INSTANCES" ]; then
  echo "RDS instances still running: ${DB_INSTANCES}"
else
  echo "no RDS instances found"
fi
