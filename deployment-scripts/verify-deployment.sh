#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Verifying deployment readiness for kubeadm cluster...${NC}"

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is available${NC}"
        return 0
    fi
}

# Function to check cluster connectivity
check_cluster() {
    echo -e "${BLUE}Checking cluster connectivity...${NC}"
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
        echo -e "${YELLOW}Current context: $(kubectl config current-context 2>/dev/null || echo 'None')${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Connected to cluster: $(kubectl config current-context)${NC}"
    
    # Check nodes
    echo -e "${BLUE}Cluster nodes:${NC}"
    kubectl get nodes -o wide
    
    return 0
}

# Function to check Docker image availability
check_image() {
    echo -e "${BLUE}Checking Docker image availability...${NC}"
    
    # Try to pull the image to verify it exists
    if docker pull kdilipkumar/trend:v22 &> /dev/null; then
        echo -e "${GREEN}✓ Docker image kdilipkumar/trend:v22 is accessible${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Could not pull image kdilipkumar/trend:v22${NC}"
        echo -e "${YELLOW}  This might be normal if the image is private or if Docker is not configured${NC}"
        echo -e "${YELLOW}  The deployment will attempt to pull the image during pod creation${NC}"
        return 0
    fi
}

# Function to validate Helm chart
validate_helm_chart() {
    echo -e "${BLUE}Validating Helm chart...${NC}"
    
    if ! helm lint ./helm-chart; then
        echo -e "${RED}✗ Helm chart validation failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Helm chart is valid${NC}"
    
    # Check if we can render templates
    echo -e "${BLUE}Testing template rendering...${NC}"
    if helm template frontend-app ./helm-chart --dry-run > /dev/null; then
        echo -e "${GREEN}✓ Helm templates render successfully${NC}"
    else
        echo -e "${RED}✗ Helm template rendering failed${NC}"
        return 1
    fi
    
    return 0
}

# Function to check cluster resources
check_resources() {
    echo -e "${BLUE}Checking cluster resources...${NC}"
    
    # Check if metrics server is available
    if kubectl top nodes &> /dev/null; then
        echo -e "${GREEN}✓ Metrics server is available${NC}"
        kubectl top nodes
    else
        echo -e "${YELLOW}⚠ Metrics server not available - resource monitoring will be limited${NC}"
    fi
    
    # Check available storage classes
    echo -e "${BLUE}Available storage classes:${NC}"
    kubectl get storageclass 2>/dev/null || echo "No storage classes found"
    
    return 0
}

# Function to check prerequisites for Istio
check_istio_prereqs() {
    echo -e "${BLUE}Checking Istio prerequisites...${NC}"
    
    # Check if Istio is already installed
    if kubectl get namespace istio-system &> /dev/null; then
        echo -e "${GREEN}✓ Istio namespace exists${NC}"
        kubectl get pods -n istio-system
    else
        echo -e "${YELLOW}⚠ Istio not installed - will be installed during deployment${NC}"
    fi
    
    return 0
}

# Main verification
main() {
    echo -e "${GREEN}=== Deployment Readiness Check ===${NC}"
    
    local errors=0
    
    # Check required tools
    echo -e "\n${BLUE}Checking required tools...${NC}"
    check_command kubectl || ((errors++))
    check_command helm || ((errors++))
    check_command docker || ((errors++))
    
    # Check cluster connectivity
    echo -e "\n${BLUE}Checking cluster...${NC}"
    check_cluster || ((errors++))
    
    # Check Docker image
    echo -e "\n${BLUE}Checking Docker image...${NC}"
    check_image
    
    # Validate Helm chart
    echo -e "\n${BLUE}Validating Helm chart...${NC}"
    validate_helm_chart || ((errors++))
    
    # Check cluster resources
    echo -e "\n${BLUE}Checking cluster resources...${NC}"
    check_resources
    
    # Check Istio prerequisites
    echo -e "\n${BLUE}Checking Istio prerequisites...${NC}"
    check_istio_prereqs
    
    # Summary
    echo -e "\n${GREEN}=== Summary ===${NC}"
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! Ready for deployment.${NC}"
        echo -e "${BLUE}To deploy, run: ./deployment-scripts/deploy.sh${NC}"
        return 0
    else
        echo -e "${RED}✗ $errors error(s) found. Please fix before deploying.${NC}"
        return 1
    fi
}

# Run main function
main
