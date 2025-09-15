#!/bin/bash

# Creative Energy Application - Kubernetes Deployment Script
# This script deploys the application to Kubernetes cluster

set -e

# Configuration
NAMESPACE="creative-energy"
MANIFESTS_DIR="k8s-manifests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN} Creative Energy - Kubernetes Deployment  ${NC}"
echo -e "${GREEN}===========================================${NC}"

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

print_warning() {
    echo -e "${BLUE}[WARNING]${NC} $1"
}

# Set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

print_status "Working directory: $PROJECT_DIR"

# Check if kubectl is available
print_status "Checking kubectl availability..."
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi
print_success "kubectl is available"

# Check cluster connectivity
print_status "Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    print_error "Unable to connect to Kubernetes cluster"
    print_error "Please check your kubeconfig and cluster status"
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Display cluster info
CLUSTER_INFO=$(kubectl config current-context)
print_status "Current context: $CLUSTER_INFO"

# Deployment order
DEPLOYMENT_FILES=(
    "namespace.yaml"
    "configmap.yaml"
    "secret.yaml"
    "pvc.yaml"
    "external-db-service.yaml"
    "service.yaml"
    "web-deployment.yaml"
    "app-deployment.yaml"
)

# Deploy unified nginx-ingress-controller with Creative Energy ingress
INGRESS_CONTROLLER_FILE="nginx-ingress-controller.yaml"

print_status "Starting deployment..."

# Deploy each manifest file
for file in "${DEPLOYMENT_FILES[@]}"; do
    manifest_path="$MANIFESTS_DIR/$file"

    if [ -f "$manifest_path" ]; then
        print_status "Applying $file..."

        if kubectl apply -f "$manifest_path"; then
            print_success "$file applied successfully"
        else
            print_error "Failed to apply $file"
            exit 1
        fi
    else
        print_warning "$manifest_path not found, skipping..."
    fi

    # Small delay between deployments
    sleep 2
done

# Deploy unified nginx-ingress-controller with Creative Energy ingress
if [ -f "$INGRESS_CONTROLLER_FILE" ]; then
    print_status "Deploying unified nginx-ingress-controller with Creative Energy ingress..."

    if kubectl apply -f "$INGRESS_CONTROLLER_FILE"; then
        print_success "Unified ingress controller and Creative Energy ingress applied successfully"
    else
        print_error "Failed to apply unified ingress controller"
        exit 1
    fi
else
    print_warning "Unified ingress controller file not found at $INGRESS_CONTROLLER_FILE"
    print_warning "Skipping ingress deployment..."
fi

echo ""
print_success "Deployment completed successfully!"

# Wait for pods to be ready
print_status "Waiting for pods to be ready..."
sleep 10

# Check deployment status
print_status "Checking deployment status..."
kubectl get all -n "$NAMESPACE"

echo ""
print_status "Pod status:"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
print_status "Service status:"
kubectl get svc -n "$NAMESPACE"

echo ""
print_status "Ingress status:"
kubectl get ingress -n "$NAMESPACE"

echo ""
print_success "Deployment verification completed!"
echo ""
echo -e "${YELLOW}Useful commands for monitoring:${NC}"
echo "kubectl get pods -n $NAMESPACE -w"
echo "kubectl logs -f deployment/web-deployment -n $NAMESPACE"
echo "kubectl logs -f deployment/app-deployment -n $NAMESPACE"
echo "kubectl describe pod <pod-name> -n $NAMESPACE"
echo ""
echo -e "${YELLOW}Access application:${NC}"
echo "External LoadBalancer IP: \$(kubectl get svc web-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Ingress domains: your_public_domain.name, your_private_domain.name"
echo ""
