# EspoCRM k3s Deployment Implementation

## Deployment Architecture

### Infrastructure
- **Cluster**: k3s on Hetzner Cloud
- **Domain**: quotennica.com (5.161.35.135)
- **SSL**: Let's Encrypt via cert-manager
- **Storage**: Hetzner Cloud Volumes (hcloud-volumes StorageClass)
- **Ingress**: NGINX Ingress Controller

### Application Components
1. **EspoCRM Application** (Deployment)
   - PHP 8.1 + Apache
   - 2 replicas for HA
   - 10Gi persistent storage for uploads/data
   
2. **MySQL Database** (StatefulSet)
   - MySQL 8.0.35
   - 20Gi persistent storage
   - Single instance (can scale later)

3. **Monitoring**
   - Prometheus metrics
   - Health checks
   - Readiness probes

## Deployment Checklist

- [x] Repository connected to GitHub
- [x] Basic k3s manifests created
- [ ] Secrets configured from .env.master
- [ ] Ingress configured for quotennica.com
- [ ] cert-manager annotations added
- [ ] GitHub Actions secrets configured
- [ ] Initial deployment via GitHub Actions
- [ ] SSL certificate provisioned
- [ ] Production smoke tests passed
- [ ] Monitoring configured
- [ ] Backup procedures documented

## Quick Commands

```bash
# Deploy to k3s
kubectl apply -f k3s/

# Check deployment status
kubectl get pods -n espocrm
kubectl logs -f deployment/espocrm -n espocrm

# Access MySQL
kubectl exec -it espocrm-mysql-0 -n espocrm -- mysql -u root -p

# Clear cache
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/clear_cache.php
```