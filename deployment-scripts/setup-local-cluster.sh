#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up local Kubernetes cluster...${NC}"

# Function to check if Docker Desktop Kubernetes is available
check_docker_desktop() {
    echo -e "${BLUE}Checking Docker Desktop Kubernetes...${NC}"
    
    # Check if docker-desktop context exists
    if kubectl config get-contexts | grep -q "docker-desktop"; then
        echo -e "${GREEN}✓ Docker Desktop Kubernetes context found${NC}"
        kubectl config use-context docker-desktop
        
        # Test connectivity
        if kubectl cluster-info &> /dev/null; then
            echo -e "${GREEN}✓ Docker Desktop Kubernetes is running${NC}"
            return 0
        else
            echo -e "${YELLOW}Docker Desktop Kubernetes context exists but cluster is not accessible${NC}"
            echo -e "${YELLOW}Please enable Kubernetes in Docker Desktop settings${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Docker Desktop Kubernetes context not found${NC}"
        return 1
    fi
}

# Function to install and start kind
setup_kind() {
    echo -e "${BLUE}Setting up kind (Kubernetes in Docker)...${NC}"
    
    # Check if kind is installed
    if ! command -v kind &> /dev/null; then
        echo -e "${YELLOW}Installing kind...${NC}"
        
        # Install kind based on OS
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            # Windows
            echo -e "${BLUE}Downloading kind for Windows...${NC}"
            curl -Lo ./kind.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
            chmod +x ./kind.exe
            export PATH="$PWD:$PATH"
        else
            # Linux/macOS
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            export PATH="$PWD:$PATH"
        fi
    fi
    
    # Create kind cluster if it doesn't exist
    if ! kind get clusters | grep -q "kind"; then
        echo -e "${YELLOW}Creating kind cluster...${NC}"
        cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
    else
        echo -e "${GREEN}✓ kind cluster already exists${NC}"
    fi
    
    # Set kubectl context to kind
    kubectl config use-context kind-kind
    
    # Verify cluster is working
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ kind cluster is running${NC}"
        return 0
    else
        echo -e "${RED}Failed to connect to kind cluster${NC}"
        return 1
    fi
}

# Function to install minikube (if available)
setup_minikube() {
    echo -e "${BLUE}Setting up minikube...${NC}"
    
    if ! command -v minikube &> /dev/null; then
        echo -e "${YELLOW}minikube not found. Please install minikube manually.${NC}"
        return 1
    fi
    
    # Start minikube
    echo -e "${YELLOW}Starting minikube...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
    
    # Set kubectl context
    kubectl config use-context minikube
    
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ minikube is running${NC}"
        return 0
    else
        echo -e "${RED}Failed to start minikube${NC}"
        return 1
    fi
}

# Main setup logic
main() {
    echo -e "${BLUE}Attempting to set up local Kubernetes cluster...${NC}"
    
    # Try Docker Desktop first
    if check_docker_desktop; then
        echo -e "${GREEN}✓ Using Docker Desktop Kubernetes${NC}"
        return 0
    fi
    
    # Try kind next
    if setup_kind; then
        echo -e "${GREEN}✓ Using kind cluster${NC}"
        return 0
    fi
    
    # Try minikube as fallback
    if setup_minikube; then
        echo -e "${GREEN}✓ Using minikube${NC}"
        return 0
    fi
    
    # If all fail, provide instructions
    echo -e "${RED}Failed to set up any local Kubernetes cluster.${NC}"
    echo -e "${YELLOW}Please manually set up one of the following:${NC}"
    echo -e "1. Enable Kubernetes in Docker Desktop"
    echo -e "2. Install and start minikube: https://minikube.sigs.k8s.io/docs/start/"
    echo -e "3. Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
    return 1
}

# Run main function
main

# Display final status
echo -e "${BLUE}Current Kubernetes context:${NC}"
kubectl config current-context
echo -e "${BLUE}Cluster info:${NC}"
kubectl cluster-info
