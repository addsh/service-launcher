#!/usr/bin/env bash
# Deploy the shared stack and every service in services.yaml.
#
# Any extra arguments are passed straight through as parameter overrides for
# the shared stack, e.g. ./scripts/deploy.sh EnableNatGateway=true
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f services.yaml ]; then
  echo "services.yaml not found, copy services.example.yaml and edit it first" >&2
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

# One artifact bucket per account and region, named so a second person running
# this against the same account does not collide with a hand-picked name.
ARTIFACT_BUCKET="service-launcher-artifacts-${ACCOUNT_ID}-${REGION}"

if ! aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" 2>/dev/null; then
  echo "creating artifact bucket ${ARTIFACT_BUCKET}"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET"
  else
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  aws s3api put-bucket-encryption --bucket "$ARTIFACT_BUCKET" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "$ARTIFACT_BUCKET" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

echo "deploying shared stack ${SHARED_STACK_NAME}"
DEPLOY_ARGS=(--template-file templates/shared.yaml --stack-name "$SHARED_STACK_NAME")
if [ "$#" -gt 0 ]; then
  DEPLOY_ARGS+=(--parameter-overrides "$@")
fi
aws cloudformation deploy "${DEPLOY_ARGS[@]}"

echo "generating nested stack template from services.yaml"
python3 generate.py

echo "packaging nested templates to s3://${ARTIFACT_BUCKET}"
aws cloudformation package \
  --template-file build/services.generated.yaml \
  --s3-bucket "$ARTIFACT_BUCKET" \
  --output-template-file build/services.packaged.yaml

echo "deploying services stack ${SERVICES_STACK_NAME}"
aws cloudformation deploy \
  --template-file build/services.packaged.yaml \
  --stack-name "$SERVICES_STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM

echo "done"
