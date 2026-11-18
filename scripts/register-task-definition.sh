#!/usr/bin/env bash
set -euo pipefail

family="${1:?Task definition family is required}"
container="${2:?Container name is required}"
image="${3:?Image is required}"

definition=$(aws ecs describe-task-definition --task-definition "$family" --include TAGS --output json |
  jq --arg container "$container" --arg image "$image" '
    .tags as $tags
    | .taskDefinition
    | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)
    | .containerDefinitions |= map(if .name == $container then .image = $image else . end)
    | if ($tags | length) > 0 then .tags = $tags else . end')

aws ecs register-task-definition --cli-input-json "$definition" \
  --query 'taskDefinition.taskDefinitionArn' --output text

# Copy the latest revision of a task definition with the container image swapped, and print the new revision ARN.