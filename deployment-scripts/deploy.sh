#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment of Frontend App with Service Mesh and Monitoring...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm is not installed. Please install helm first.${NC}"
    exit 1
fi

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t frontend-app:latest .

# Create namespace first
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-app
  labels:
    istio-injection: enabled
    environment: production
    team: frontend
EOF

# Install Istio if not already installed
echo -e "${YELLOW}Checking Istio installation...${NC}"
if ! kubectl get namespace istio-system &> /dev/null; then
    echo -e "${YELLOW}Installing Istio...${NC}"
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH
    istioctl install --set values.defaultRevision=default
    cd ..
fi

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install the application
echo -e "${YELLOW}Installing application with Helm...${NC}"
helm upgrade --install frontend-app ./helm-chart \
    --namespace frontend-app \
    --create-namespace \
    --wait \
    --timeout 600s

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=frontend-app -n frontend-app --timeout=300s

# Display deployment status
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Getting service information...${NC}"

kubectl get all -n frontend-app
kubectl get ingress -n frontend-app

echo -e "${GREEN}Frontend App is now deployed with:${NC}"
echo -e "✓ Service Mesh (Istio)"
echo -e "✓ Monitoring (Prometheus & Grafana)"
echo -e "✓ Security (RBAC, Network Policies)"
echo -e "✓ Auto-scaling (HPA)"
echo -e "✓ Resource Management"

echo -e "${YELLOW}Access URLs:${NC}"
echo -e "Frontend: https://frontend.example.com"
echo -e "Grafana: kubectl port-forward -n frontend-app svc/grafana 3000:80"
echo -e "Prometheus: kubectl port-forward -n frontend-app svc/prometheus-server 9090:80"