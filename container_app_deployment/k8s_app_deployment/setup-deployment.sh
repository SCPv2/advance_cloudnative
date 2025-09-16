#!/bin/bash
# Samsung Cloud Platform v2 - Kubernetes Deployment Setup Script
# This script is executed on the bastion server to deploy the k8s application
# It processes template files and applies user-specific configurations
#
# Usage: ./setup-deployment.sh
#
# This script will be generated with actual values by env_setup.ps1 and
# included in bastion userdata for automatic execution

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

# User variables (will be replaced by env_setup.ps1)
PRIVATE_DOMAIN="your_private_domain.name"
PUBLIC_DOMAIN="your_public_domain.name"
OBJECT_STORAGE_ACCESS_KEY="put_your_authentificate_access_key_here"
OBJECT_STORAGE_SECRET_KEY="put_your_authentificate_secret_key_here"
OBJECT_STORAGE_BUCKET_ID="put_your_account_id_here"
CONTAINER_REGISTRY_ENDPOINT="your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com"
USER_PUBLIC_IP="your_public_ip/32"
KEYPAIR_NAME="mykey"

# Fixed values
OBJECT_STORAGE_BUCKET_NAME="ceweb"
OBJECT_STORAGE_REGION="kr-west-1"
OBJECT_STORAGE_PRIVATE_ENDPOINT="https://object-store.private.kr-west1.e.samsungsdscloud.com"
OBJECT_STORAGE_PUBLIC_ENDPOINT="https://object-store.kr-west1.e.samsungsdscloud.com"
DB_HOST="db.${PRIVATE_DOMAIN}"
DB_PASSWORD="cedbadmin123!"
DB_USER="cedbadmin"
NAMESPACE="creative-energy"

log_info "=========================================="
log_info "Starting Kubernetes Deployment Setup"
log_info "=========================================="
log_info "Private Domain: ${PRIVATE_DOMAIN}"
log_info "Public Domain: ${PUBLIC_DOMAIN}"
log_info "Container Registry: ${CONTAINER_REGISTRY_ENDPOINT}"
log_info "=========================================="

# kubectl check removed - will be configured manually
log_warning "Skipping kubectl check - please ensure kubectl/kubeconfig is configured manually"

# Navigate to the k8s deployment directory
cd /home/rocky/advance_cloudnative/container_app_deployment/k8s_app_deployment

log_info "Processing ALL template files with user values..."

# 1. Process template files (.template -> actual files)
log_info "Processing template files..."
for template_file in $(find . -name "*.template" -type f); do
    output_file="${template_file%.template}"
    log_info "Processing: $template_file -> $output_file"
    cp "$template_file" "$output_file"
done

# 2. Update ConfigMap with correct domains
log_info "Updating ConfigMap..."
sed -i "s|your_public_domain.name|${PUBLIC_DOMAIN}|g" k8s-manifests/configmap.yaml
sed -i "s|your_private_domain.name|${PRIVATE_DOMAIN}|g" k8s-manifests/configmap.yaml

# 3. Update external-db-service.yaml
log_info "Updating external database service..."
sed -i "s|your_private_domain.name|${PRIVATE_DOMAIN}|g" k8s-manifests/external-db-service.yaml

# 4. Update deployments with container registry
log_info "Updating deployments with container registry..."
if [ -f k8s-manifests/app-deployment.yaml ]; then
    sed -i "s|your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com|${CONTAINER_REGISTRY_ENDPOINT}|g" k8s-manifests/app-deployment.yaml
    sed -i "s|myregistry-[a-zA-Z0-9\-]*\.scr\.private\.[a-zA-Z0-9\-]*\.e\.samsungsdscloud\.com|${CONTAINER_REGISTRY_ENDPOINT}|g" k8s-manifests/app-deployment.yaml
fi
if [ -f k8s-manifests/web-deployment.yaml ]; then
    sed -i "s|your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com|${CONTAINER_REGISTRY_ENDPOINT}|g" k8s-manifests/web-deployment.yaml
    sed -i "s|myregistry-[a-zA-Z0-9\-]*\.scr\.private\.[a-zA-Z0-9\-]*\.e\.samsungsdscloud\.com|${CONTAINER_REGISTRY_ENDPOINT}|g" k8s-manifests/web-deployment.yaml
fi

# 5. Update build scripts with container registry
log_info "Updating build scripts..."
for script_file in scripts/build-images.sh scripts/push-images.sh scripts/build-app-gitbased.sh scripts/deploy-from-bastion.sh; do
    if [ -f "$script_file" ]; then
        log_info "Updating script: $script_file"
        sed -i "s|your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com|${CONTAINER_REGISTRY_ENDPOINT}|g" "$script_file"
        sed -i "s|myregistry-[a-zA-Z0-9\-]*\.scr\.private\.[a-zA-Z0-9\-]*\.e\.samsungsdscloud\.com|${CONTAINER_REGISTRY_ENDPOINT}|g" "$script_file"
    fi
done

# 6. Update Dockerfile with Object Storage variables
log_info "Updating Dockerfile..."
if [ -f dockerfiles/Dockerfile.app ]; then
    log_info "Updating Dockerfile.app with Object Storage configuration"
    sed -i "s|put_your_authentificate_access_key_here|${OBJECT_STORAGE_ACCESS_KEY}|g" dockerfiles/Dockerfile.app
    sed -i "s|put_your_authentificate_secret_key_here|${OBJECT_STORAGE_SECRET_KEY}|g" dockerfiles/Dockerfile.app
    sed -i "s|ceweb|${OBJECT_STORAGE_BUCKET_NAME}|g" dockerfiles/Dockerfile.app
    sed -i "s|put_your_account_id_here|${OBJECT_STORAGE_BUCKET_ID}|g" dockerfiles/Dockerfile.app
    sed -i "s|https://object-store.private.kr-west1.e.samsungsdscloud.com|${OBJECT_STORAGE_PRIVATE_ENDPOINT}|g" dockerfiles/Dockerfile.app
    sed -i "s|your_public_domain.name|${PUBLIC_DOMAIN}|g" dockerfiles/Dockerfile.app
    sed -i "s|your_private_domain.name|${PRIVATE_DOMAIN}|g" dockerfiles/Dockerfile.app
fi

# 7. Update registry credentials secret
log_info "Updating registry credentials..."

# Perform Docker login using Access Keys
log_info "Performing Docker login to Container Registry..."
if [ -n "${OBJECT_STORAGE_ACCESS_KEY}" ] && [ -n "${OBJECT_STORAGE_SECRET_KEY}" ] && [ -n "${CONTAINER_REGISTRY_ENDPOINT}" ]; then
    # Samsung Cloud Platform Container Registry uses the same Access Keys as Object Storage
    log_info "Logging in to Container Registry: ${CONTAINER_REGISTRY_ENDPOINT}"
    echo "${OBJECT_STORAGE_SECRET_KEY}" | docker login "${CONTAINER_REGISTRY_ENDPOINT}" \
        --username "${OBJECT_STORAGE_ACCESS_KEY}" \
        --password-stdin

    if [ $? -eq 0 ]; then
        log_success "Docker login successful"
    else
        log_error "Docker login failed"
        log_warning "Registry credentials will use placeholder values"
    fi
else
    log_warning "Container Registry credentials not available (OBJECT_STORAGE_ACCESS_KEY, OBJECT_STORAGE_SECRET_KEY, or CONTAINER_REGISTRY_ENDPOINT missing)"
    log_warning "Registry credentials will use placeholder values"
fi

if [ -f ~/.docker/config.json ]; then
    # Check if namespace exists, create if not
    if ! kubectl get namespace creative-energy > /dev/null 2>&1; then
        kubectl create namespace creative-energy
        log_info "Created namespace: creative-energy"
    fi

    # Delete existing secret if it exists
    if kubectl get secret registry-credentials -n creative-energy > /dev/null 2>&1; then
        kubectl delete secret registry-credentials -n creative-energy
        log_info "Removed existing registry credentials"
    fi

    # Create new secret from Docker config
    kubectl create secret generic registry-credentials \
        --from-file=.dockerconfigjson=/home/rocky/.docker/config.json \
        --type=kubernetes.io/dockerconfigjson -n creative-energy
    log_info "Registry credentials updated from Docker config"
else
    log_warning "Docker config not found. Please run 'docker login' first"
    log_warning "Registry credentials will use placeholder values"
fi

# 8. Update nginx-ingress-controller.yaml
log_info "Updating Ingress controller..."
if [ -f nginx-ingress-controller.yaml ]; then
    sed -i "s|your_public_domain.name|${PUBLIC_DOMAIN}|g" nginx-ingress-controller.yaml
    sed -i "s|your_private_domain.name|${PRIVATE_DOMAIN}|g" nginx-ingress-controller.yaml
fi

# 9. Create master_config.json
log_info "Creating master_config.json..."
cat > /tmp/master_config.json << EOF
{
  "object_storage": {
    "access_key_id": "${OBJECT_STORAGE_ACCESS_KEY}",
    "secret_access_key": "${OBJECT_STORAGE_SECRET_KEY}",
    "region": "${OBJECT_STORAGE_REGION}",
    "bucket_name": "${OBJECT_STORAGE_BUCKET_NAME}",
    "bucket_string": "${OBJECT_STORAGE_BUCKET_ID}",
    "private_endpoint": "${OBJECT_STORAGE_PRIVATE_ENDPOINT}",
    "public_endpoint": "${OBJECT_STORAGE_PUBLIC_ENDPOINT}",
    "folders": {
      "media": "media/img",
      "audition": "files/audition"
    }
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "${PUBLIC_DOMAIN}",
      "private_domain_name": "${PRIVATE_DOMAIN}"
    },
    "database": {
      "host": "${DB_HOST}",
      "port": "2866",
      "name": "cedb",
      "user": "${DB_USER}"
    },
    "container_registry": {
      "endpoint": "${CONTAINER_REGISTRY_ENDPOINT}",
      "region": "kr-west-1"
    }
  }
}
EOF

# 10. Create master-config ConfigMap YAML
log_info "Creating master-config ConfigMap YAML..."
cat > k8s-manifests/master-config-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: master-config
  namespace: ${NAMESPACE}
data:
  master_config.json: |
$(cat /tmp/master_config.json | sed 's/^/    /')
EOF

log_success "=========================================="
log_success "Configuration Processing Completed!"
log_success "=========================================="
log_info "All template files have been updated with your values:"
log_info "  ✅ Template files processed (.template -> actual files)"
log_info "  ✅ ConfigMaps updated with domains"
log_info "  ✅ External DB service configured"
log_info "  ✅ Container registry endpoints set"
log_info "  ✅ Build scripts updated"
log_info "  ✅ Dockerfile updated with Object Storage config"
log_info "  ✅ Master config generated"
log_info ""
log_warning "=========================================="
log_warning "NEXT STEP: MANUAL KUBERNETES DEPLOYMENT"
log_warning "=========================================="
log_info "📋 Please follow these steps to deploy:"
log_info ""
log_info "1. Create namespace:"
log_info "   kubectl create namespace ${NAMESPACE}"
log_info ""
log_info "2. Apply configurations (in order):"
log_info "   kubectl apply -f k8s-manifests/configmap.yaml"
log_info "   kubectl apply -f k8s-manifests/master-config-configmap.yaml"
log_info "   kubectl apply -f k8s-manifests/secret.yaml"
log_info ""
log_info "3. Apply infrastructure:"
log_info "   kubectl apply -f k8s-manifests/pvc.yaml"
log_info "   kubectl apply -f k8s-manifests/external-db-service.yaml"
log_info "   kubectl apply -f k8s-manifests/service.yaml"
log_info ""
log_info "4. Deploy applications:"
log_info "   kubectl apply -f k8s-manifests/web-deployment.yaml"
log_info "   kubectl apply -f k8s-manifests/app-deployment.yaml"
log_info ""
log_info "5. (Optional) Apply Ingress:"
log_info "   kubectl apply -f nginx-ingress-controller.yaml"
log_info ""
log_info "📖 For detailed instructions, see: README.md"
log_info ""
log_info "Configuration Summary:"
log_info "  - Namespace: ${NAMESPACE}"
log_info "  - Public Domain: ${PUBLIC_DOMAIN}"
log_info "  - Private Domain: ${PRIVATE_DOMAIN}"
log_info "  - Container Registry: ${CONTAINER_REGISTRY_ENDPOINT}"
log_info "  - Database: ${DB_HOST}"
log_info ""
log_success "After deployment, access your application at:"
log_success "  → http://www.${PUBLIC_DOMAIN}"
log_success "  → http://${PUBLIC_DOMAIN}"
