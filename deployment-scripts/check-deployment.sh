#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Checking deployment status...${NC}"

# Function to check pod status
check_pods() {
    echo -e "${BLUE}Checking pod status in frontend-app namespace...${NC}"
    
    if ! kubectl get namespace frontend-app &> /dev/null; then
        echo -e "${RED}✗ Namespace 'frontend-app' does not exist${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Pods in frontend-app namespace:${NC}"
    kubectl get pods -n frontend-app -o wide
    
    # Check if all pods are running
    NOT_RUNNING=$(kubectl get pods -n frontend-app --no-headers | grep -v "Running\|Completed" | wc -l)
    if [ "$NOT_RUNNING" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Some pods are not running. Checking details...${NC}"
        kubectl get pods -n frontend-app | grep -v "Running\|Completed"
        return 1
    else
        echo -e "${GREEN}✓ All pods are running${NC}"
        return 0
    fi
}

# Function to check services
check_services() {
    echo -e "${BLUE}Checking services...${NC}"
    kubectl get services -n frontend-app
    
    # Get NodePort if service type is NodePort
    NODEPORT=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$NODEPORT" ]; then
        echo -e "${GREEN}✓ Service exposed on NodePort: $NODEPORT${NC}"
        
        # Get node IP
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        if [ -z "$NODE_IP" ]; then
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        fi
        
        if [ -n "$NODE_IP" ]; then
            echo -e "${BLUE}Access URL: http://$NODE_IP:$NODEPORT${NC}"
        fi
    fi
}

# Function to check Istio status
check_istio() {
    echo -e "${BLUE}Checking Istio status...${NC}"
    
    if kubectl get namespace istio-system &> /dev/null; then
        echo -e "${GREEN}✓ Istio namespace exists${NC}"
        echo -e "${YELLOW}Istio pods:${NC}"
        kubectl get pods -n istio-system
        
        # Check if Istio gateway is available
        if kubectl get gateway -n frontend-app &> /dev/null; then
            echo -e "${GREEN}✓ Istio gateway configured${NC}"
            kubectl get gateway -n frontend-app
        fi
        
        # Check virtual service
        if kubectl get virtualservice -n frontend-app &> /dev/null; then
            echo -e "${GREEN}✓ Istio virtual service configured${NC}"
            kubectl get virtualservice -n frontend-app
        fi
    else
        echo -e "${YELLOW}⚠ Istio not installed${NC}"
    fi
}

# Function to check monitoring
check_monitoring() {
    echo -e "${BLUE}Checking monitoring components...${NC}"
    
    # Check Prometheus
    if kubectl get pods -n frontend-app | grep -q prometheus; then
        echo -e "${GREEN}✓ Prometheus is running${NC}"
    else
        echo -e "${YELLOW}⚠ Prometheus not found${NC}"
    fi
    
    # Check Grafana
    if kubectl get pods -n frontend-app | grep -q grafana; then
        echo -e "${GREEN}✓ Grafana is running${NC}"
    else
        echo -e "${YELLOW}⚠ Grafana not found${NC}"
    fi
}

# Function to test application connectivity
test_connectivity() {
    echo -e "${BLUE}Testing application connectivity...${NC}"
    
    # Get service details
    SERVICE_TYPE=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.type}' 2>/dev/null)
    
    if [ "$SERVICE_TYPE" = "NodePort" ]; then
        NODEPORT=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        
        if [ -n "$NODE_IP" ] && [ -n "$NODEPORT" ]; then
            echo -e "${BLUE}Testing connectivity to http://$NODE_IP:$NODEPORT${NC}"
            if curl -s --connect-timeout 5 "http://$NODE_IP:$NODEPORT" > /dev/null; then
                echo -e "${GREEN}✓ Application is accessible${NC}"
            else
                echo -e "${YELLOW}⚠ Application not accessible via NodePort (this might be normal if the app is still starting)${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Service type is $SERVICE_TYPE - use port-forward for testing${NC}"
        echo -e "${BLUE}Run: kubectl port-forward -n frontend-app svc/frontend-service 8080:80${NC}"
    fi
}

# Function to show access instructions
show_access_instructions() {
    echo -e "\n${GREEN}=== Access Instructions ===${NC}"
    
    # Application access
    SERVICE_TYPE=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.type}' 2>/dev/null)
    if [ "$SERVICE_TYPE" = "NodePort" ]; then
        NODEPORT=$(kubectl get svc frontend-service -n frontend-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        echo -e "${BLUE}Frontend Application:${NC} http://$NODE_IP:$NODEPORT"
    else
        echo -e "${BLUE}Frontend Application:${NC} kubectl port-forward -n frontend-app svc/frontend-service 8080:80"
        echo -e "  Then access: http://localhost:8080"
    fi
    
    # Monitoring access
    echo -e "${BLUE}Grafana Dashboard:${NC} kubectl port-forward -n frontend-app svc/grafana 3000:80"
    echo -e "  Then access: http://localhost:3000 (admin/admin123!)"
    
    echo -e "${BLUE}Prometheus:${NC} kubectl port-forward -n frontend-app svc/prometheus-server 9090:80"
    echo -e "  Then access: http://localhost:9090"
}

# Main function
main() {
    echo -e "${GREEN}=== Deployment Status Check ===${NC}"
    
    check_pods
    echo ""
    
    check_services
    echo ""
    
    check_istio
    echo ""
    
    check_monitoring
    echo ""
    
    test_connectivity
    echo ""
    
    show_access_instructions
}

# Run main function
main
