#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment of Frontend App with Service Mesh and Monitoring...${NC}"

# Function to check cluster connectivity
check_cluster_connectivity() {
    echo -e "${BLUE}Checking Kubernetes cluster connectivity...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Cannot connect to Kubernetes cluster.${NC}"
        echo -e "${YELLOW}Current context: $(kubectl config current-context 2>/dev/null || echo 'None')${NC}"
        echo -e "${YELLOW}Available contexts:${NC}"
        kubectl config get-contexts 2>/dev/null || echo "No contexts available"
        echo -e "${RED}Please ensure your Kubernetes cluster is running and accessible.${NC}"
        echo -e "${YELLOW}For local development, you can:${NC}"
        echo -e "  - Start minikube: minikube start"
        echo -e "  - Enable Docker Desktop Kubernetes"
        echo -e "  - Use kind: kind create cluster"
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to cluster: $(kubectl config current-context)${NC}"
}

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

# Check cluster connectivity
check_cluster_connectivity

# Function to verify kubeadm cluster
verify_kubeadm_cluster() {
    echo -e "${BLUE}Verifying kubeadm cluster setup...${NC}"
    CURRENT_CONTEXT=$(kubectl config current-context)
    echo -e "${YELLOW}Current context: $CURRENT_CONTEXT${NC}"

    # Check if cluster is accessible
    if ! kubectl get nodes &> /dev/null; then
        echo -e "${RED}Cannot access cluster nodes. Please check your kubeconfig.${NC}"
        exit 1
    fi

    # Display cluster info
    echo -e "${GREEN}✓ Cluster is accessible${NC}"
    echo -e "${BLUE}Cluster nodes:${NC}"
    kubectl get nodes -o wide

    # Check if cluster has sufficient resources
    echo -e "${BLUE}Checking cluster resources...${NC}"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available - continuing anyway"

    # Verify cluster is ready
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -vc " Ready ")
    if [ "$NOT_READY_NODES" -gt 0 ]; then
        echo -e "${YELLOW}Warning: Some nodes are not ready${NC}"
        kubectl get nodes
    fi
}

# Verify kubeadm cluster
verify_kubeadm_cluster

# Skip Docker build - using existing image kdilipkumar/trend:v22
echo -e "${GREEN}✓ Using existing Docker image: kdilipkumar/trend:v22${NC}"

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

# Function to install Istio with better error handling
install_istio() {
    echo -e "${YELLOW}Checking Istio installation...${NC}"

    if kubectl get namespace istio-system &> /dev/null; then
        echo -e "${GREEN}✓ Istio is already installed${NC}"
        return 0
    fi

    echo -e "${YELLOW}Installing Istio...${NC}"

    # Download Istio if not already present
    if [ ! -d "istio-*" ]; then
        echo -e "${BLUE}Downloading Istio...${NC}"
        curl -L https://istio.io/downloadIstio | sh -
    fi

    # Find the Istio directory
    ISTIO_DIR=$(find . -maxdepth 1 -name "istio-*" -type d | head -1)
    if [ -z "$ISTIO_DIR" ]; then
        echo -e "${RED}Failed to find Istio directory${NC}"
        exit 1
    fi

    cd "$ISTIO_DIR"
    export PATH=$PWD/bin:$PATH

    echo -e "${BLUE}Installing Istio with minimal profile for better resource usage...${NC}"

    # Use minimal profile for resource-constrained environments
    if ! istioctl install --set values.pilot.resources.requests.memory=128Mi \
                          --set values.pilot.resources.requests.cpu=50m \
                          --set values.global.proxy.resources.requests.memory=64Mi \
                          --set values.global.proxy.resources.requests.cpu=10m \
                          --set values.gateways.istio-ingressgateway.resources.requests.memory=64Mi \
                          --set values.gateways.istio-ingressgateway.resources.requests.cpu=10m \
                          --skip-confirmation \
                          --timeout=10m; then
        echo -e "${RED}Istio installation failed. Checking cluster resources...${NC}"
        kubectl top nodes 2>/dev/null || echo "Cannot get node metrics"
        kubectl get pods -n istio-system
        echo -e "${YELLOW}You may need to increase cluster resources or use a lighter service mesh alternative.${NC}"
        exit 1
    fi

    cd ..
    echo -e "${GREEN}✓ Istio installed successfully${NC}"
}

# Install Istio
install_istio

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
    --set image.repository=kdilipkumar/trend \
    --set image.tag=v22 \
    --set image.pullPolicy=Always \
    --wait \
    --timeout 600s

# Function to wait for pods and display status
wait_for_deployment() {
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"

    # Wait for pods with better error handling
    if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=frontend-app -n frontend-app --timeout=300s; then
        echo -e "${RED}Pods failed to become ready within timeout. Checking status...${NC}"
        kubectl get pods -n frontend-app
        kubectl describe pods -n frontend-app
        echo -e "${YELLOW}You may need to check resource constraints or image pull issues.${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ All pods are ready${NC}"
    return 0
}

# Function to display deployment status
display_status() {
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${YELLOW}Getting service information...${NC}"

    kubectl get all -n frontend-app
    kubectl get ingress -n frontend-app 2>/dev/null || echo "No ingress resources found"

    echo -e "${GREEN}Frontend App is now deployed with:${NC}"
    echo -e "✓ Service Mesh (Istio)"
    echo -e "✓ Monitoring (Prometheus & Grafana)"
    echo -e "✓ Security (RBAC, Network Policies)"
    echo -e "✓ Auto-scaling (HPA)"
    echo -e "✓ Resource Management"

    echo -e "${YELLOW}Access URLs:${NC}"

    # Get NodePort information
    NODEPORT=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

    if [ -n "$NODEPORT" ] && [ -n "$NODE_IP" ]; then
        echo -e "${GREEN}Frontend Application: http://$NODE_IP:$NODEPORT${NC}"
        echo -e "${BLUE}You can access the application directly using the above URL${NC}"
    else
        echo -e "Frontend: kubectl port-forward -n frontend-app svc/frontend-service 8080:80"
        echo -e "${BLUE}Then access: http://localhost:8080${NC}"
    fi

    echo -e "Grafana: kubectl port-forward -n frontend-app svc/grafana 3000:80"
    echo -e "${BLUE}Then access: http://localhost:3000 (admin/admin123!)${NC}"

    echo -e "Prometheus: kubectl port-forward -n frontend-app svc/prometheus-server 9090:80"
    echo -e "${BLUE}Then access: http://localhost:9090${NC}"

    echo -e "\n${GREEN}=== Next Steps ===${NC}"
    echo -e "${BLUE}1. Check deployment status: ./deployment-scripts/check-deployment.sh${NC}"
    echo -e "${BLUE}2. Monitor logs: kubectl logs -f deployment/frontend-app -n frontend-app${NC}"
    echo -e "${BLUE}3. Scale application: kubectl scale deployment frontend-app --replicas=5 -n frontend-app${NC}"
}

# Wait for deployment and display status
if wait_for_deployment; then
    display_status
else
    echo -e "${RED}Deployment completed with issues. Check the logs above for details.${NC}"
    exit 1
fi