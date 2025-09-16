#!/bin/bash
# Build and Deploy App Server with Git-based Multi-stage Dockerfile
# This script builds the app server image from GitHub source and deploys to Kubernetes

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration - Replace with your actual registry
REGISTRY="{{CONTAINER_REGISTRY_ENDPOINT}}"
IMAGE_NAME="ceweb/creative-energy-app"
IMAGE_TAG="gitbased"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
DOCKERFILE="${PROJECT_DIR}/dockerfiles/Dockerfile.app.multistage"
DEPLOYMENT_YAML="${PROJECT_DIR}/k8s-manifests/app-deployment-gitbased.yaml"

log_info "=========================================="
log_info "Git-based App Server Build and Deploy"
log_info "=========================================="
log_info "Registry: ${REGISTRY}"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Dockerfile: ${DOCKERFILE}"
log_info "=========================================="

# Step 1: Check if Dockerfile exists
if [ ! -f "${DOCKERFILE}" ]; then
    log_error "Dockerfile not found: ${DOCKERFILE}"
    exit 1
fi

# Step 2: Build Docker image
log_info "Building Docker image from GitHub source..."
docker build -f "${DOCKERFILE}" -t "${FULL_IMAGE}" "${PROJECT_DIR}/dockerfiles"

if [ $? -eq 0 ]; then
    log_success "Docker image built successfully"
else
    log_error "Docker build failed"
    exit 1
fi

# Step 3: Push image to registry
log_info "Pushing image to registry..."
docker push "${FULL_IMAGE}"

if [ $? -eq 0 ]; then
    log_success "Image pushed to registry successfully"
else
    log_error "Failed to push image to registry"
    exit 1
fi

# Step 4: Update deployment YAML with actual registry
log_info "Updating deployment YAML with registry information..."
sed -i "s|myregistry-xxxxxxxx|${REGISTRY%%.scr.private.kr-west1.e.samsungsdscloud.com}|g" "${DEPLOYMENT_YAML}"

# Step 5: Apply Kubernetes deployment
log_info "Applying Kubernetes deployment..."
kubectl apply -f "${DEPLOYMENT_YAML}"

if [ $? -eq 0 ]; then
    log_success "Deployment applied successfully"
else
    log_error "Failed to apply deployment"
    exit 1
fi

# Step 6: Wait for rollout to complete
log_info "Waiting for deployment rollout..."
kubectl rollout status deployment/app-deployment -n creative-energy --timeout=300s

if [ $? -eq 0 ]; then
    log_success "Deployment rollout completed successfully"
else
    log_warning "Rollout did not complete within timeout"
fi

# Step 7: Check pod status
log_info "Checking pod status..."
kubectl get pods -n creative-energy -l component=app-server

# Step 8: Test health endpoint
log_info "Testing health endpoint..."
POD_NAME=$(kubectl get pods -n creative-energy -l component=app-server -o jsonpath='{.items[0].metadata.name}')

if [ -n "${POD_NAME}" ]; then
    log_info "Testing pod: ${POD_NAME}"
    kubectl exec "${POD_NAME}" -n creative-energy -- curl -s http://localhost:3000/health | jq '.' || log_warning "Health check failed"
else
    log_warning "No pods found for health check"
fi

log_info "=========================================="
log_success "Build and deployment process completed!"
log_info "=========================================="
log_info "To check deployment status:"
log_info "  kubectl get deployment app-deployment -n creative-energy"
log_info "  kubectl get pods -n creative-energy -l component=app-server"
log_info "  kubectl logs -n creative-energy -l component=app-server --tail=50"
log_info "=========================================="