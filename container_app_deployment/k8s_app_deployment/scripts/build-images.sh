#!/bin/bash

# Creative Energy Application - Container Image Build Script
# This script builds Docker images for the web server and app server

set -e

# Configuration
REGISTRY_URL="{{CONTAINER_REGISTRY_ENDPOINT}}"
PROJECT_NAME="ceweb"
IMAGE_TAG=${1:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} Creative Energy - Image Build Script ${NC}"
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

# Set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

print_status "Working directory: $PROJECT_DIR"

# Build web server image
print_status "Building web server image..."
docker build \
    -f dockerfiles/Dockerfile.web \
    -t "$REGISTRY_URL/$PROJECT_NAME/web-server:$IMAGE_TAG" \
    -t "$REGISTRY_URL/$PROJECT_NAME/web-server:latest" \
    .

if [ $? -eq 0 ]; then
    print_success "Web server image built successfully"
else
    print_error "Failed to build web server image"
    exit 1
fi

# Build app server image
print_status "Building app server image..."
docker build \
    -f dockerfiles/Dockerfile.app \
    -t "$REGISTRY_URL/$PROJECT_NAME/app-server:$IMAGE_TAG" \
    -t "$REGISTRY_URL/$PROJECT_NAME/app-server:latest" \
    .

if [ $? -eq 0 ]; then
    print_success "App server image built successfully"
else
    print_error "Failed to build app server image"
    exit 1
fi

# Display built images
print_status "Built images:"
docker images | grep "$REGISTRY_URL/$PROJECT_NAME"

echo ""
print_success "Image build completed successfully!"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Push images to registry: ./scripts/push-images.sh $IMAGE_TAG"
echo "2. Deploy to Kubernetes: ./scripts/deploy.sh"
echo ""