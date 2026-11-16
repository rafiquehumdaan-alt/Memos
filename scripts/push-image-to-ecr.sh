#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${1:?Local image tag is required}"
ECR_REPOSITORY_URI="${2:?ECR repository URI is required}"
IMAGE_TAG="${3:?Image tag is required}"

for IMAGE_URI in "$ECR_REPOSITORY_URI:$IMAGE_TAG" "$ECR_REPOSITORY_URI:latest"; do
  echo "Tagging Docker image as $IMAGE_URI..."
  docker tag "$LOCAL_IMAGE" "$IMAGE_URI"

  echo "Pushing Docker image to ECR..."
  docker push "$IMAGE_URI"

  echo "Image pushed: $IMAGE_URI"
done

MEMOS_IMAGE=$(awk '/^FROM / { print $2; exit }' app/Dockerfile)
SETUP_IMAGE_URI="$ECR_REPOSITORY_URI:setup-latest"

docker build --platform linux/amd64 --provenance=false \
  --build-arg "MEMOS_IMAGE=$MEMOS_IMAGE" \
  --tag "$SETUP_IMAGE_URI" ./setup

docker push "$SETUP_IMAGE_URI"

# Tag the Docker image and push it to Amazon ECR.