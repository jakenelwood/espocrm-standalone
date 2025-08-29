# EspoCRM Standalone

[![Deploy to k3s](https://github.com/brian/espocrm-standalone/actions/workflows/deploy.yml/badge.svg)](https://github.com/brian/espocrm-standalone/actions/workflows/deploy.yml)

A production-ready, standalone deployment of EspoCRM designed for k3s clusters. This repository provides a complete CRM solution with MySQL database, automated CI/CD, and comprehensive monitoring.

## 🚀 Features

- **Complete CRM System**: Full EspoCRM functionality with all modules
- **Production Ready**: Security-first approach with RBAC and network policies
- **k3s Optimized**: Designed specifically for k3s clusters on Hetzner Cloud
- **Automated Deployment**: GitHub Actions CI/CD pipeline with staging and production
- **MySQL Database**: StatefulSet deployment with persistent storage
- **Health Monitoring**: Built-in health checks and Prometheus metrics
- **API Integration**: RESTful API for integration with other services

## 📋 Prerequisites

- k3s cluster (tested on v1.28+)
- kubectl configured with cluster access
- Hetzner Cloud volumes storage class
- NGINX Ingress Controller
- cert-manager for SSL certificates

## 🏗️ Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/brian/espocrm-standalone.git
cd espocrm-standalone
```

### 2. Configure Secrets

```bash
# Copy and edit the secrets file
cp k3s/secrets.yaml k3s/secrets.local.yaml

# Edit k3s/secrets.local.yaml with your passwords
# NEVER commit real passwords to git!
```

### 3. Deploy to k3s

```bash
# Create namespace and RBAC
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/rbac.yaml

# Deploy MySQL database
kubectl apply -f k3s/mysql/

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=espocrm-mysql -n espocrm --timeout=300s

# Deploy EspoCRM
kubectl apply -f k3s/configmap.yaml
kubectl apply -f k3s/secrets.local.yaml  # Your edited secrets
kubectl apply -f k3s/pvc.yaml
kubectl apply -f k3s/service.yaml
kubectl apply -f k3s/deployment.yaml
kubectl apply -f k3s/ingress.yaml

# Verify deployment
kubectl get pods -n espocrm
kubectl get ingress -n espocrm
```

## 🔧 Configuration

### Environment Variables

Key environment variables in `k3s/deployment.yaml`:

- `ESPOCRM_DATABASE_HOST`: MySQL host (default: espocrm-mysql)
- `ESPOCRM_DATABASE_NAME`: Database name (default: espocrm)
- `ESPOCRM_SITE_URL`: Your CRM URL (update in deployment.yaml)
- `ESPOCRM_ADMIN_USERNAME`: Admin username (default: admin)

### Ingress Configuration

Update `k3s/ingress.yaml` with your domain:

```yaml
spec:
  rules:
  - host: crm.yourdomain.com  # Change this
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: espocrm
            port:
              number: 80
```

### Storage Configuration

The deployment uses Hetzner Cloud volumes. Adjust storage sizes in:
- `k3s/pvc.yaml`: Application data (default: 10Gi)
- `k3s/mysql/statefulset.yaml`: Database storage (default: 20Gi)

## 🚢 CI/CD Pipeline

The repository includes a complete GitHub Actions workflow that:

1. **Validates** k3s manifests with kubeval
2. **Security scans** with kubesec and Trivy
3. **Builds** Docker image and pushes to GitHub Container Registry
4. **Tests** application health
5. **Deploys** to staging (develop branch)
6. **Deploys** to production (main branch)

### Setup CI/CD

1. Set GitHub repository secrets:
   - `KUBECONFIG_STAGING`: Base64-encoded kubeconfig for staging
   - `KUBECONFIG_PRODUCTION`: Base64-encoded kubeconfig for production

2. Push to trigger deployment:
   ```bash
   git push origin develop  # Deploy to staging
   git push origin main     # Deploy to production
   ```

## 📊 Monitoring

### Health Checks

The application exposes health endpoints:
- `/api/v1/App/health` - Application health status

### Prometheus Metrics

Metrics are exposed on port 80 at `/api/v1/App/health` with annotations for Prometheus scraping.

### Logs

Access logs:
```bash
# Application logs
kubectl logs -f deployment/espocrm -n espocrm

# MySQL logs
kubectl logs -f statefulset/espocrm-mysql -n espocrm
```

## 🔌 API Integration

EspoCRM provides a RESTful API for integration with other services.

### Authentication

```bash
# Get API key from EspoCRM admin panel
# Then use in requests:
curl -H "X-Api-Key: YOUR_API_KEY" \
     https://crm.yourdomain.com/api/v1/Contact
```

### Common Endpoints

```bash
# Get contacts
GET /api/v1/Contact

# Create lead
POST /api/v1/Lead
Content-Type: application/json
{
  "firstName": "John",
  "lastName": "Doe",
  "emailAddress": "john@example.com"
}

# Update account
PUT /api/v1/Account/{id}
```

### Webhook Integration

EspoCRM can send webhooks to external services. Configure in Admin > Webhooks.

## 🛠️ Maintenance

### Backup Database

```bash
# Create backup
kubectl exec -n espocrm espocrm-mysql-0 -- \
  mysqldump -u root -p${MYSQL_ROOT_PASSWORD} espocrm > backup.sql

# Restore backup
kubectl exec -i -n espocrm espocrm-mysql-0 -- \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} espocrm < backup.sql
```

### Clear Cache

```bash
kubectl exec -n espocrm deployment/espocrm -- \
  php /var/www/html/clear_cache.php
```

### Rebuild Application

```bash
kubectl exec -n espocrm deployment/espocrm -- \
  php /var/www/html/rebuild.php
```

### Update EspoCRM

1. Update image version in `Dockerfile`
2. Build and push new image
3. Update deployment:
   ```bash
   kubectl set image deployment/espocrm espocrm=ghcr.io/brian/espocrm-standalone:new-version -n espocrm
   ```

## 🔒 Security

- **Network Policies**: Restricts traffic between pods
- **RBAC**: Limited permissions for service accounts
- **Security Context**: Non-root user, read-only filesystem where possible
- **Secret Management**: Sensitive data in Kubernetes secrets
- **Pod Security Standards**: Enforced restricted policy
- **SSL/TLS**: Automated with cert-manager and Let's Encrypt

## 🐛 Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n espocrm POD_NAME

# Check logs
kubectl logs -n espocrm POD_NAME

# Check events
kubectl get events -n espocrm --sort-by='.lastTimestamp'
```

### Database Connection Issues

```bash
# Test MySQL connection
kubectl exec -it -n espocrm deployment/espocrm -- \
  mysql -h espocrm-mysql -u espocrm -p

# Check MySQL pod
kubectl logs -n espocrm statefulset/espocrm-mysql
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n espocrm

# Check available storage
kubectl get storageclass
```

## 📚 Documentation

- [Official EspoCRM Documentation](https://docs.espocrm.com/)
- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Migration Guide](docs/MIGRATION.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](LICENSE.txt) file for details.

## 🆘 Support

For issues and questions:
- Open an issue in this repository
- Check EspoCRM forums: https://forum.espocrm.com/
- Commercial support: https://www.espocrm.com/support/

## 🏷️ Version

Current EspoCRM Version: 8.0.0

---

Built for production k3s deployments on Hetzner Cloud infrastructure.# Deployment test 
