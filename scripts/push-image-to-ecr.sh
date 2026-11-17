#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${1:?Local image tag is required}"
ECR_REPOSITORY_URI="${2:?ECR repository URI is required}"
IMAGE_TAG="${3:?Image tag is required}"

APP_IMAGE_URI="$ECR_REPOSITORY_URI:$IMAGE_TAG"
SETUP_IMAGE_URI="$ECR_REPOSITORY_URI:$IMAGE_TAG-setup"

echo "Tagging Docker image as $APP_IMAGE_URI..."
docker tag "$LOCAL_IMAGE" "$APP_IMAGE_URI"

echo "Pushing Docker image to ECR..."
docker push "$APP_IMAGE_URI"

echo "Image pushed: $APP_IMAGE_URI"

MEMOS_IMAGE=$(awk '/^FROM / { print $2; exit }' app/Dockerfile)

docker build --platform linux/amd64 --provenance=false \
  --build-arg "MEMOS_IMAGE=$MEMOS_IMAGE" \
  --tag "$SETUP_IMAGE_URI" ./setup

docker push "$SETUP_IMAGE_URI"

# Tag the app and setup images with the release tag and push them to Amazon ECR.