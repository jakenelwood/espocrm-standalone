#!/bin/bash
set -e

# EspoCRM Standalone Deployment Script
# Usage: ./scripts/deploy.sh [environment]

ENVIRONMENT=${1:-production}
NAMESPACE="espocrm"

if [ "$ENVIRONMENT" == "staging" ]; then
    NAMESPACE="espocrm-staging"
fi

echo "🚀 Deploying EspoCRM to $ENVIRONMENT (namespace: $NAMESPACE)"

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }

# Verify cluster connection
echo "🔌 Verifying cluster connection..."
kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Cannot connect to Kubernetes cluster. Check your kubeconfig." >&2; exit 1; }

# Create namespace if it doesn't exist
echo "📦 Creating namespace if needed..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply configurations
echo "🔧 Applying configurations..."
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/rbac.yaml
kubectl apply -f k3s/configmap.yaml

# Check for secrets
if [ ! -f "k3s/secrets.local.yaml" ]; then
    echo "⚠️  Warning: k3s/secrets.local.yaml not found!"
    echo "   Copy k3s/secrets.yaml to k3s/secrets.local.yaml and update with real passwords"
    exit 1
fi

# Apply secrets
echo "🔐 Applying secrets..."
kubectl apply -f k3s/secrets.local.yaml

# Deploy MySQL
echo "🗄️  Deploying MySQL database..."
kubectl apply -f k3s/mysql/service.yaml
kubectl apply -f k3s/mysql/statefulset.yaml

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app=espocrm-mysql -n $NAMESPACE --timeout=300s

# Deploy EspoCRM
echo "🚀 Deploying EspoCRM application..."
kubectl apply -f k3s/pvc.yaml
kubectl apply -f k3s/service.yaml
kubectl apply -f k3s/deployment.yaml
kubectl apply -f k3s/ingress.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for EspoCRM to be ready..."
kubectl rollout status deployment/espocrm -n $NAMESPACE --timeout=600s

# Get ingress information
echo "📊 Deployment Summary:"
echo "===================="
kubectl get pods -n $NAMESPACE
echo ""
echo "Ingress Information:"
kubectl get ingress -n $NAMESPACE

# Get URL
URL=$(kubectl get ingress -n $NAMESPACE espocrm -o jsonpath='{.spec.rules[0].host}')
echo ""
echo "✅ EspoCRM deployed successfully!"
echo "🌐 Access your CRM at: https://$URL"
echo ""
echo "📝 Default credentials:"
echo "   Username: admin"
echo "   Password: (check your secrets.local.yaml)"
echo ""
echo "🔍 To check logs:"
echo "   kubectl logs -f deployment/espocrm -n $NAMESPACE"
echo ""
echo "🧹 To clear cache:"
echo "   kubectl exec -n $NAMESPACE deployment/espocrm -- php /var/www/html/clear_cache.php"