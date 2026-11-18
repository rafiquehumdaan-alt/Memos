#!/usr/bin/env bash
set -euo pipefail

cluster="${1:?ECS cluster name is required}"
service="${2:?ECS service name is required}"
family="${3:?Setup task family is required}"
image_tag="${4:?Image tag is required}"

network=$(aws ecs describe-services \
  --cluster "$cluster" \
  --services "$service" \
  --query 'services[0].networkConfiguration' \
  --output json)

if ! jq -e '.awsvpcConfiguration.subnets | length > 0' <<< "$network" >/dev/null; then
  echo "No ECS network configuration found. Run Terraform apply first." >&2
  exit 1
fi

repository_uri=$(aws ecr describe-repositories --repository-names memos \
  --query 'repositories[0].repositoryUri' --output text)

setup_digest=$(aws ecr describe-images \
  --repository-name memos \
  --image-ids "imageTag=$image_tag-setup" \
  --query 'imageDetails[0].imageDigest' --output text)

task_definition=$(bash scripts/register-task-definition.sh "$family" setup "$repository_uri@$setup_digest")

task=$(aws ecs run-task \
  --cluster "$cluster" \
  --launch-type FARGATE \
  --task-definition "$task_definition" \
  --network-configuration "$network" \
  --output json |
  jq -er '.tasks[0].taskArn // error(.failures | tostring)')

echo "Waiting for database setup task $task"
aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task"

details=$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task" --output json)
if ! jq -e 'any(.tasks[0].containers[]?; .name == "setup" and .exitCode == 0)' \
  <<< "$details" >/dev/null; then
  jq '.tasks[0] | {stoppedReason, containers: [.containers[] | {name, exitCode, reason}]}' \
    <<< "$details" >&2
  echo "Database setup failed. Check the setup container logs in CloudWatch." >&2
  exit 1
fi

echo "Database setup finished successfully."
