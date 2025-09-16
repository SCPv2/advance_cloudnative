#!/bin/bash

# Creative Energy Application - Kubernetes Cleanup Script
# This script removes the application from Kubernetes cluster

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

echo -e "${RED}=========================================${NC}"
echo -e "${RED} Creative Energy - Kubernetes Cleanup   ${NC}"
echo -e "${RED}=========================================${NC}"

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
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Confirm deletion
echo ""
print_warning "This will delete all Creative Energy application resources from the cluster!"
print_warning "Namespace: $NAMESPACE"
echo ""
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled"
    exit 0
fi

# Check if namespace exists
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    print_status "Namespace $NAMESPACE found, proceeding with cleanup..."
else
    print_warning "Namespace $NAMESPACE not found"
    exit 0
fi

# Cleanup order (reverse of deployment)
CLEANUP_FILES=(
    "ingress.yaml"
    "app-deployment.yaml"
    "web-deployment.yaml"
    "service.yaml"
    "external-db-service.yaml"
    "pvc.yaml"
    "secret.yaml"
    "configmap.yaml"
)

print_status "Starting cleanup..."

# Delete each manifest file
for file in "${CLEANUP_FILES[@]}"; do
    manifest_path="$MANIFESTS_DIR/$file"

    if [ -f "$manifest_path" ]; then
        print_status "Deleting resources from $file..."

        if kubectl delete -f "$manifest_path" --ignore-not-found=true; then
            print_success "Resources from $file deleted successfully"
        else
            print_warning "Some resources from $file may not have been deleted"
        fi
    else
        print_warning "$manifest_path not found, skipping..."
    fi

    # Small delay between deletions
    sleep 2
done

# Wait for resources to be deleted
print_status "Waiting for resources to be cleaned up..."
sleep 10

# Delete namespace (this will delete any remaining resources)
print_status "Deleting namespace $NAMESPACE..."
if kubectl delete namespace "$NAMESPACE" --ignore-not-found=true; then
    print_success "Namespace $NAMESPACE deleted successfully"
else
    print_warning "Namespace $NAMESPACE may not have been deleted"
fi

# Wait for namespace deletion
print_status "Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; do
    echo -n "."
    sleep 5
done
echo ""

print_success "Cleanup completed successfully!"

# Verify cleanup
print_status "Verifying cleanup..."
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    print_warning "Namespace $NAMESPACE still exists"
    kubectl get all -n "$NAMESPACE"
else
    print_success "All resources have been cleaned up"
fi

echo ""
print_success "Creative Energy application has been removed from the cluster"
echo ""