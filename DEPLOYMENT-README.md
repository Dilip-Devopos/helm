# Frontend Application Deployment on Kubeadm Cluster

This repository contains a comprehensive Helm chart for deploying a React frontend application with service mesh (Istio) and monitoring (Prometheus/Grafana) on a kubeadm Kubernetes cluster.

## 🚀 Quick Start

### Prerequisites

- Kubeadm Kubernetes cluster (running and accessible)
- kubectl configured to access your cluster
- Helm 3.x installed
- Docker (for image verification)

### Deployment Steps

1. **Verify deployment readiness:**
   ```bash
   ./deployment-scripts/verify-deployment.sh
   ```

2. **Deploy the application:**
   ```bash
   ./deployment-scripts/deploy.sh
   ```

3. **Check deployment status:**
   ```bash
   ./deployment-scripts/check-deployment.sh
   ```

## 📋 What Gets Deployed

### Core Application
- **Frontend App**: React application using image `kdilipkumar/trend:v22`
- **Service**: NodePort service (port 30080) for direct access
- **Deployment**: 3 replicas with rolling update strategy
- **HPA**: Horizontal Pod Autoscaler for automatic scaling

### Service Mesh (Istio)
- **Istio Control Plane**: Lightweight configuration for kubeadm
- **Gateway**: HTTP/HTTPS ingress gateway
- **VirtualService**: Traffic routing configuration
- **DestinationRule**: Load balancing and circuit breaker

### Monitoring Stack
- **Prometheus**: Metrics collection (optimized resources)
- **Grafana**: Visualization dashboard (admin/admin123!)
- **ServiceMonitor**: Automatic metrics discovery

### Security & Networking
- **RBAC**: Service accounts and role bindings
- **Network Policies**: Pod-to-pod communication rules
- **Security Context**: Non-root containers with read-only filesystem

## 🔧 Configuration

### Key Configuration Changes for Kubeadm

The deployment has been optimized for kubeadm clusters:

1. **Resource Requirements**: Reduced memory/CPU requests and limits
2. **Storage**: Disabled persistent volumes (uses emptyDir)
3. **Service Type**: NodePort for direct access without load balancer
4. **Istio**: Lightweight configuration with reduced resource usage
5. **TLS**: Simplified configuration without cert-manager dependency

### Customization

Edit `helm-chart/values.yaml` to customize:

```yaml
# Application settings
app:
  replicas: 3  # Number of replicas

# Image settings
image:
  repository: kdilipkumar/trend
  tag: v22

# Service settings
service:
  type: NodePort
  nodePort: 30080

# Resource limits
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

## 🌐 Access Methods

### Direct Access (NodePort)
```bash
# Get node IP and port
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Application URL: http://$NODE_IP:30080"
```

### Port Forwarding
```bash
# Frontend application
kubectl port-forward -n frontend-app svc/frontend-service 8080:80
# Access: http://localhost:8080

# Grafana dashboard
kubectl port-forward -n frontend-app svc/grafana 3000:80
# Access: http://localhost:3000 (admin/admin123!)

# Prometheus
kubectl port-forward -n frontend-app svc/prometheus-server 9090:80
# Access: http://localhost:9090
```

## 🔍 Monitoring & Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n frontend-app -o wide
```

### View Logs
```bash
# Application logs
kubectl logs -f deployment/frontend-app -n frontend-app

# Istio sidecar logs
kubectl logs -f deployment/frontend-app -c istio-proxy -n frontend-app
```

### Debug Issues
```bash
# Describe pod for events
kubectl describe pod <pod-name> -n frontend-app

# Check resource usage
kubectl top pods -n frontend-app

# Verify service endpoints
kubectl get endpoints -n frontend-app
```

### Common Issues

1. **Pods stuck in Pending**: Check node resources and scheduling
2. **ImagePullBackOff**: Verify image `kdilipkumar/trend:v22` is accessible
3. **Service not accessible**: Check NodePort and firewall rules
4. **Istio issues**: Verify Istio installation and sidecar injection

## 📊 Scaling

### Manual Scaling
```bash
# Scale to 5 replicas
kubectl scale deployment frontend-app --replicas=5 -n frontend-app
```

### Auto Scaling
HPA is configured to scale based on CPU/memory usage:
- Min replicas: 2
- Max replicas: 10
- Target CPU: 70%
- Target Memory: 80%

## 🔄 Updates

### Update Application Image
```bash
# Update to new image version
helm upgrade frontend-app ./helm-chart \
  --namespace frontend-app \
  --set image.tag=v23 \
  --wait
```

### Rolling Back
```bash
# View rollout history
kubectl rollout history deployment/frontend-app -n frontend-app

# Rollback to previous version
kubectl rollout undo deployment/frontend-app -n frontend-app
```

## 🧹 Cleanup

### Remove Application
```bash
helm uninstall frontend-app -n frontend-app
kubectl delete namespace frontend-app
```

### Remove Istio (if needed)
```bash
istioctl uninstall --purge
kubectl delete namespace istio-system
```

## 📝 Notes

- The deployment uses optimized resource settings for kubeadm clusters
- Persistent storage is disabled to avoid storage class dependencies
- TLS/SSL is simplified for easier setup
- All components are deployed in the `frontend-app` namespace
- The application is accessible via NodePort 30080 by default

For production deployments, consider:
- Enabling persistent storage
- Setting up proper TLS certificates
- Configuring resource limits based on actual usage
- Setting up backup and disaster recovery procedures
