#!/bin/bash

# Creative Energy Application - Container Registry Push Script
# This script pushes Docker images to the container registry

set -e

# Configuration
REGISTRY_URL="myregistry-xxxxxxxx.scr.private.kr-west1.e.samsungsdscloud.com"
PROJECT_NAME="ceweb"
IMAGE_TAG=${1:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} Creative Energy - Image Push Script  ${NC}"
echo -e "${GREEN}======================================${NC}"

# Function to print status
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
print_status "Checking Docker availability..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
print_success "Docker is available"

# Login to container registry
print_status "Logging in to container registry..."
print_status "Registry: $REGISTRY_URL"

# Note: Make sure to configure docker login credentials beforehand
# docker login $REGISTRY_URL

# Check if images exist locally
WEB_IMAGE="$REGISTRY_URL/$PROJECT_NAME/web-server:$IMAGE_TAG"
APP_IMAGE="$REGISTRY_URL/$PROJECT_NAME/app-server:$IMAGE_TAG"

print_status "Checking if images exist locally..."

if ! docker image inspect "$WEB_IMAGE" > /dev/null 2>&1; then
    print_error "Web server image $WEB_IMAGE not found locally. Please build images first."
    exit 1
fi

if ! docker image inspect "$APP_IMAGE" > /dev/null 2>&1; then
    print_error "App server image $APP_IMAGE not found locally. Please build images first."
    exit 1
fi

# Push web server image
print_status "Pushing web server image..."
docker push "$WEB_IMAGE"

if [ $? -eq 0 ]; then
    print_success "Web server image pushed successfully"
else
    print_error "Failed to push web server image"
    exit 1
fi

# Push web server latest tag if not latest
if [ "$IMAGE_TAG" != "latest" ]; then
    print_status "Pushing web server latest tag..."
    docker push "$REGISTRY_URL/$PROJECT_NAME/web-server:latest"
fi

# Push app server image
print_status "Pushing app server image..."
docker push "$APP_IMAGE"

if [ $? -eq 0 ]; then
    print_success "App server image pushed successfully"
else
    print_error "Failed to push app server image"
    exit 1
fi

# Push app server latest tag if not latest
if [ "$IMAGE_TAG" != "latest" ]; then
    print_status "Pushing app server latest tag..."
    docker push "$REGISTRY_URL/$PROJECT_NAME/app-server:latest"
fi

echo ""
print_success "Image push completed successfully!"
echo ""
echo -e "${YELLOW}Pushed images:${NC}"
echo "- $WEB_IMAGE"
echo "- $APP_IMAGE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Deploy to Kubernetes: ./scripts/deploy.sh"
echo ""