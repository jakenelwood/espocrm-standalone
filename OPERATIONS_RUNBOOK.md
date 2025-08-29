# EspoCRM k3s Operations Runbook

## Production Deployment Status
- **URL**: https://quotennica.com
- **IP Address**: 5.161.35.135
- **Cluster**: k3s on Hetzner Cloud
- **GitHub Repository**: https://github.com/jakenelwood/espocrm-standalone

## Quick Commands

### Check Deployment Status
```bash
# View all resources
kubectl get all -n espocrm

# Check pod logs
kubectl logs -f deployment/espocrm -n espocrm
kubectl logs -f statefulset/espocrm-mysql -n espocrm

# Check certificate status
kubectl get certificate -n espocrm
```

### Access Application
```bash
# Port forward for local testing
kubectl port-forward svc/espocrm 8080:80 -n espocrm

# Access MySQL
kubectl exec -it espocrm-mysql-0 -n espocrm -- mysql -u root -pespocrm_root_password_2025
```

### Maintenance Tasks

#### Clear EspoCRM Cache
```bash
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/clear_cache.php
```

#### Rebuild Application
```bash
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/rebuild.php
```

#### Run Cron Jobs Manually
```bash
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/cron.php
```

### Backup & Restore

#### Backup Database
```bash
# Create backup
kubectl exec -n espocrm espocrm-mysql-0 -- mysqldump -u root -pespocrm_root_password_2025 espocrm > backup-$(date +%Y%m%d).sql

# Backup application data
kubectl cp espocrm/espocrm-<pod-id>:/var/www/html/data ./espocrm-data-backup
```

#### Restore Database
```bash
kubectl exec -i -n espocrm espocrm-mysql-0 -- mysql -u root -pespocrm_root_password_2025 espocrm < backup.sql
```

### Troubleshooting

#### Pod Not Starting
```bash
# Check events
kubectl get events -n espocrm --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name> -n espocrm

# Check init container logs
kubectl logs <pod-name> -n espocrm -c init-permissions
kubectl logs <pod-name> -n espocrm -c wait-for-mysql
```

#### MySQL Issues
```bash
# Check MySQL status
kubectl exec espocrm-mysql-0 -n espocrm -- mysqladmin -u root -pespocrm_root_password_2025 status

# View MySQL logs
kubectl logs espocrm-mysql-0 -n espocrm --tail=50

# Restart MySQL
kubectl delete pod espocrm-mysql-0 -n espocrm
```

#### Certificate Issues
```bash
# Check certificate status
kubectl describe certificate espocrm-tls -n espocrm

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ACME challenges
kubectl get challenges -n espocrm
```

### Scaling

#### Scale Application Replicas
```bash
# Scale up
kubectl scale deployment espocrm -n espocrm --replicas=3

# Scale down
kubectl scale deployment espocrm -n espocrm --replicas=1
```

### Updates & Deployments

#### Manual Deployment
```bash
# Apply all manifests
kubectl apply -f k3s/

# Update specific component
kubectl apply -f k3s/deployment.yaml
```

#### GitHub Actions Deployment
```bash
# Trigger deployment from GitHub
git push origin main

# Check GitHub Actions status
gh run list --repo jakenelwood/espocrm-standalone
gh run view <run-id> --repo jakenelwood/espocrm-standalone
```

### Monitoring

#### Resource Usage
```bash
# Check pod resource usage
kubectl top pods -n espocrm

# Check node resources
kubectl top nodes
```

#### Application Health
```bash
# Check health endpoint
kubectl exec -n espocrm deployment/espocrm -- curl -f http://localhost/api/v1/App/health
```

## Configuration

### Environment Variables
Environment variables are stored in:
- **Secrets**: `k3s/secrets.yaml` (DO NOT COMMIT)
- **ConfigMap**: `k3s/configmap.yaml`

### Key Secrets
- `espocrm-mysql-secret`: Database credentials
- `espocrm-admin-secret`: Admin user credentials
- `espocrm-api-secret`: API key for integrations

### Update Secrets
```bash
# Edit secrets (be careful!)
kubectl edit secret espocrm-mysql-secret -n espocrm

# Apply new secrets
kubectl apply -f k3s/secrets.yaml
```

## Security

### Pod Security
- Namespace uses `baseline` Pod Security Standards
- Containers run as non-root user (www-data, UID 33)
- Network policies restrict pod-to-pod communication

### Access Control
- RBAC configured with minimal permissions
- Service account: `espocrm-sa`

## Disaster Recovery

### Full Backup
```bash
#!/bin/bash
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
kubectl exec -n espocrm espocrm-mysql-0 -- mysqldump -u root -pespocrm_root_password_2025 --all-databases > $BACKUP_DIR/mysql-dump.sql

# Backup persistent volumes
kubectl get pvc -n espocrm -o yaml > $BACKUP_DIR/pvcs.yaml

# Backup configurations
kubectl get configmap,secret -n espocrm -o yaml > $BACKUP_DIR/configs.yaml

echo "Backup completed: $BACKUP_DIR"
```

### Restore from Backup
```bash
#!/bin/bash
BACKUP_DIR=$1

# Restore database
kubectl exec -i -n espocrm espocrm-mysql-0 -- mysql -u root -pespocrm_root_password_2025 < $BACKUP_DIR/mysql-dump.sql

# Restart application
kubectl rollout restart deployment/espocrm -n espocrm
```

## Contacts

- **GitHub Repository**: https://github.com/jakenelwood/espocrm-standalone
- **Production URL**: https://quotennica.com
- **k3s Cluster**: 5.161.38.104:6443

## Common Issues & Solutions

### Issue: Pods stuck in Init state
**Solution**: Check MySQL connectivity, ensure MySQL is running and accessible.

### Issue: Certificate not issuing
**Solution**: Check DNS records point to correct IP (5.161.35.135), verify ACME challenge.

### Issue: Application not accessible
**Solution**: Check ingress configuration, verify SSL certificate is ready, check network policies.

### Issue: High memory usage
**Solution**: Clear cache, check for memory leaks, scale horizontally if needed.

## Maintenance Windows

Recommended maintenance windows:
- **Daily**: Cron jobs run automatically every minute
- **Weekly**: Clear cache and optimize database
- **Monthly**: Full backup and security updates