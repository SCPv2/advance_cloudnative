#!/bin/bash
# Test the new ConfigMap-based master_config.json approach

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log_info "=========================================="
log_info "Testing ConfigMap-based master_config.json"
log_info "=========================================="

# Step 1: Apply the master-config ConfigMap
log_info "Step 1: Applying master-config ConfigMap..."
kubectl apply -f ../k8s-manifests/master-config-configmap.yaml

if [ $? -eq 0 ]; then
    log_success "ConfigMap applied successfully"
else
    log_error "Failed to apply ConfigMap"
    exit 1
fi

# Step 2: Build and push new Docker image
log_info "Step 2: Building new Docker image without hardcoded config..."
cd ../dockerfiles
docker build -f Dockerfile.app -t {{CONTAINER_REGISTRY_ENDPOINT}}/ceweb/creative-energy-app:configmap .

if [ $? -eq 0 ]; then
    log_success "Docker image built successfully"
else
    log_error "Docker build failed"
    exit 1
fi

# Step 3: Push image
log_info "Step 3: Pushing Docker image..."
docker push {{CONTAINER_REGISTRY_ENDPOINT}}/ceweb/creative-energy-app:configmap

if [ $? -eq 0 ]; then
    log_success "Image pushed successfully"
else
    log_error "Failed to push image"
    exit 1
fi

# Step 4: Update deployment to use new image tag
log_info "Step 4: Updating deployment to use configmap tag..."
kubectl set image deployment/app-deployment app-server={{CONTAINER_REGISTRY_ENDPOINT}}/ceweb/creative-energy-app:configmap -n creative-energy

# Step 5: Wait for rollout
log_info "Step 5: Waiting for deployment rollout..."
kubectl rollout status deployment/app-deployment -n creative-energy --timeout=300s

# Step 6: Test the configuration
log_info "Step 6: Testing the new configuration..."
sleep 10

POD_NAME=$(kubectl get pods -n creative-energy -l component=app-server -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    log_info "Testing pod: $POD_NAME"

    # Check if master_config.json is mounted correctly
    log_info "Checking if master_config.json is mounted..."
    kubectl exec "$POD_NAME" -n creative-energy -- cat /home/rocky/ceweb/web-server/master_config.json > /tmp/mounted_config.json

    if [ $? -eq 0 ]; then
        log_success "master_config.json is accessible"

        # Validate JSON structure
        if jq . /tmp/mounted_config.json >/dev/null 2>&1; then
            log_success "master_config.json is valid JSON"

            # Check for template variables (should be replaced)
            if grep -q "{{" /tmp/mounted_config.json; then
                log_warning "Template variables found - k8s_config_manager may not have processed the file"
                jq . /tmp/mounted_config.json
            else
                log_success "Template variables appear to be processed"
            fi
        else
            log_error "master_config.json is not valid JSON"
            cat /tmp/mounted_config.json
        fi
    else
        log_error "Cannot access master_config.json"
    fi

    # Test health endpoint
    log_info "Testing health endpoint..."
    kubectl exec "$POD_NAME" -n creative-energy -- curl -s http://localhost:3000/health | jq '{success, message, database}' || log_warning "Health check failed"

else
    log_error "No pods found for testing"
fi

log_info "=========================================="
log_success "ConfigMap approach test completed!"
log_info "=========================================="