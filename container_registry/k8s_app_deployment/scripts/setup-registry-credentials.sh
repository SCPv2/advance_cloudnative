#!/bin/bash
# Samsung Cloud Platform v2 - Container Registry Credentials Setup
# This script configures Docker login and Kubernetes registry credentials
# Run this script AFTER adding the VM to Container Registry ACL

set -e

# Color functions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if script is run from correct directory
if [ ! -f "../setup-deployment.sh" ]; then
    log_error "This script must be run from the k8s_app_deployment/scripts directory"
    log_error "Please run: cd /home/rocky/advance_cloudnative/container_registry/k8s_app_deployment/scripts"
    exit 1
fi

# Source variables from parent directory setup script
cd ..
if [ -f setup-deployment.sh ]; then
    # Extract variables from setup-deployment.sh
    PRIVATE_DOMAIN=$(grep 'PRIVATE_DOMAIN=' setup-deployment.sh | head -1 | cut -d'"' -f2)
    PUBLIC_DOMAIN=$(grep 'PUBLIC_DOMAIN=' setup-deployment.sh | head -1 | cut -d'"' -f2)
    OBJECT_STORAGE_ACCESS_KEY=$(grep 'OBJECT_STORAGE_ACCESS_KEY=' setup-deployment.sh | head -1 | cut -d'"' -f2)
    OBJECT_STORAGE_SECRET_KEY=$(grep 'OBJECT_STORAGE_SECRET_KEY=' setup-deployment.sh | head -1 | cut -d'"' -f2)
    CONTAINER_REGISTRY_ENDPOINT=$(grep 'CONTAINER_REGISTRY_ENDPOINT=' setup-deployment.sh | head -1 | cut -d'"' -f2)
    NAMESPACE=$(grep 'NAMESPACE=' setup-deployment.sh | head -1 | cut -d'"' -f2)
else
    log_error "setup-deployment.sh not found. Please run setup-deployment.sh first."
    exit 1
fi

log_info "=========================================="
log_info "Container Registry Credentials Setup"
log_info "=========================================="
log_info "Container Registry: ${CONTAINER_REGISTRY_ENDPOINT}"
log_info "Namespace: ${NAMESPACE}"
log_info "=========================================="

# Check if variables are properly set
if [ -z "${OBJECT_STORAGE_ACCESS_KEY}" ] || [ -z "${OBJECT_STORAGE_SECRET_KEY}" ] || [ -z "${CONTAINER_REGISTRY_ENDPOINT}" ]; then
    log_error "Required variables not found in setup-deployment.sh"
    log_error "Please ensure setup-deployment.sh has been executed successfully"
    exit 1
fi

# Check Docker installation
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please run setup-deployment.sh first."
    exit 1
fi

# Check kubectl installation
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please run setup-deployment.sh first."
    exit 1
fi

# Perform Docker login
log_info "Performing Docker login to Container Registry..."
log_info "Registry: ${CONTAINER_REGISTRY_ENDPOINT}"
log_info "Username: ${OBJECT_STORAGE_ACCESS_KEY}"

if echo "${OBJECT_STORAGE_SECRET_KEY}" | docker login "${CONTAINER_REGISTRY_ENDPOINT}" \
    --username "${OBJECT_STORAGE_ACCESS_KEY}" \
    --password-stdin; then
    log_success "Docker login successful"
else
    log_error "Docker login failed"
    log_error "Please check:"
    log_error "  1. Container Registry ACL includes this VM"
    log_error "  2. Access Key and Secret Key are correct"
    log_error "  3. Container Registry endpoint is accessible"
    exit 1
fi

# Verify Docker config was created
if [ ! -f ~/.docker/config.json ]; then
    log_error "Docker config file not created after login"
    exit 1
fi

log_success "Docker configuration file created: ~/.docker/config.json"

# Check if namespace exists, create if not
log_info "Checking Kubernetes namespace: ${NAMESPACE}"
if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
    kubectl create namespace ${NAMESPACE}
    log_info "Created namespace: ${NAMESPACE}"
else
    log_info "Namespace ${NAMESPACE} already exists"
fi

# Delete existing secret if it exists
if kubectl get secret registry-credentials -n ${NAMESPACE} > /dev/null 2>&1; then
    kubectl delete secret registry-credentials -n ${NAMESPACE}
    log_info "Removed existing registry credentials secret"
fi

# Create new secret from Docker config
log_info "Creating Kubernetes registry credentials secret..."
kubectl create secret generic registry-credentials \
    --from-file=.dockerconfigjson=/home/rocky/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson -n ${NAMESPACE}

log_success "Registry credentials secret created successfully"

# Verify secret creation
log_info "Verifying registry credentials secret..."
if kubectl get secret registry-credentials -n ${NAMESPACE} > /dev/null 2>&1; then
    log_success "Registry credentials secret verified"

    # Display secret details (without showing sensitive data)
    echo ""
    log_info "Secret details:"
    kubectl describe secret registry-credentials -n ${NAMESPACE} | grep -E "(Name:|Namespace:|Type:|Data:)"
else
    log_error "Failed to verify registry credentials secret"
    exit 1
fi

log_success "=========================================="
log_success "Container Registry Setup Completed!"
log_success "=========================================="
log_info "Next steps:"
log_info "  1. Build and push container images to registry"
log_info "  2. Deploy Kubernetes applications"
log_info "  3. Verify image pull from private registry"
log_info ""
log_info "Registry endpoint: ${CONTAINER_REGISTRY_ENDPOINT}"
log_info "Kubernetes namespace: ${NAMESPACE}"
log_info "Registry secret: registry-credentials"