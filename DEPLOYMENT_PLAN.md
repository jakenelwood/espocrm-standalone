# EspoCRM K3s Production Deployment Plan

## Executive Summary
This plan details the production deployment of EspoCRM to the k3s cluster at quotennica.com (5.161.35.135), following the proven patterns from K3S_DEPLOYMENT_PLAYBOOK.md with adaptations for EspoCRM's specific requirements.

## Pre-Deployment Checklist
- [x] Repository audited and complete with all EspoCRM files
- [x] K3s cluster operational (4 nodes, control plane at 5.161.38.104)
- [x] DNS configured (quotennica.com → 5.161.35.135)
- [x] Storage class available (hcloud-volumes)
- [x] Ingress controller deployed (nginx at 5.161.35.135)
- [ ] GitHub repository created
- [ ] Secrets configured
- [ ] CI/CD pipeline ready

## Phase 1: Repository Setup (10 mins)

### 1.1 Create GitHub Repository
```bash
# Create repository
gh repo create espocrm-standalone --public --source=. --remote=origin --push

# Configure repository settings
gh repo edit --enable-issues --enable-wiki --enable-projects
```

### 1.2 Configure Repository Secrets
```bash
# Production secrets
gh secret set KUBECONFIG_PRODUCTION < ~/.kube/config
gh secret set MYSQL_ROOT_PASSWORD --body "espocrm_root_password_2025"
gh secret set MYSQL_PASSWORD --body "espocrm_password_2025"
gh secret set ESPOCRM_ADMIN_PASSWORD --body "admin_password_2025"
gh secret set ESPOCRM_API_KEY --body "42a92c1380230c97b35eeaebab9ce57b"
```

## Phase 2: K3s Manifests Configuration (20 mins)

### 2.1 Namespace & Security
- Update namespace.yaml with Pod Security Standards
- Configure RBAC for service account
- Implement network policies (default deny + specific allows)

### 2.2 MySQL StatefulSet
- Configure MySQL 8.0 with persistent storage (20Gi)
- Set up proper initialization and configuration
- Implement health checks and resource limits

### 2.3 EspoCRM Deployment
- Configure PHP 8.1 + Apache container
- Mount persistent volumes for data/uploads (10Gi)
- Set up init containers for permissions
- Configure health/readiness/startup probes
- Resource allocation: 512Mi-1Gi memory, 250m-1000m CPU

### 2.4 Ingress Configuration
- Configure HTTPS ingress for quotennica.com
- Set up cert-manager for Let's Encrypt SSL
- Configure proper annotations for session affinity

## Phase 3: CI/CD Pipeline Setup (15 mins)

### 3.1 GitHub Actions Workflow
- Multi-stage pipeline (validate → build → test → deploy)
- Security scanning with Trivy
- Kubernetes manifest validation
- Automated rollback on failure

### 3.2 Docker Build Configuration
- Multi-stage Dockerfile for optimal image size
- Security hardening (non-root user, minimal base image)
- Health check integration

## Phase 4: Deployment Execution (30 mins)

### 4.1 Initial Deployment Steps
```bash
# 1. Apply base infrastructure
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/rbac.yaml
kubectl apply -f k3s/configmap.yaml

# 2. Create secrets from .env.master
kubectl create secret generic espocrm-secrets -n espocrm \
  --from-env-file=.env.master

# 3. Deploy MySQL
kubectl apply -f k3s/mysql/

# 4. Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=espocrm-mysql -n espocrm --timeout=300s

# 5. Deploy EspoCRM
kubectl apply -f k3s/pvc.yaml
kubectl apply -f k3s/deployment.yaml
kubectl apply -f k3s/service.yaml

# 6. Configure ingress with cert-manager
kubectl apply -f k3s/ingress.yaml
```

### 4.2 Post-Deployment Configuration
- Initialize EspoCRM database
- Configure cron jobs for scheduled tasks
- Set up email integration
- Configure API access

## Phase 5: Validation & Testing (20 mins)

### 5.1 Infrastructure Validation
- [ ] All pods running and healthy
- [ ] PVCs bound and mounted
- [ ] Services accessible internally
- [ ] Ingress routing working

### 5.2 Application Testing
- [ ] Web UI accessible at https://quotennica.com
- [ ] Admin login functional
- [ ] Database connectivity verified
- [ ] File uploads working
- [ ] Email sending/receiving functional
- [ ] API endpoints responding
- [ ] Cron jobs executing

### 5.3 Performance Testing
- [ ] Page load times < 2 seconds
- [ ] API response times < 500ms
- [ ] Concurrent user handling (test with 10 users)

## Phase 6: Monitoring & Operations (15 mins)

### 6.1 Monitoring Setup
- Configure Prometheus ServiceMonitor
- Set up Grafana dashboards
- Configure alerting rules
- Set up log aggregation

### 6.2 Backup Configuration
- Automated MySQL backups (daily)
- File system backups for uploads
- Configuration backups
- Disaster recovery procedures

### 6.3 Operational Runbook
- Troubleshooting procedures
- Scaling guidelines
- Update procedures
- Emergency response

## Risk Mitigation

### Potential Issues & Solutions
1. **Database Connection Issues**
   - Solution: Verify MySQL service DNS, check credentials
   
2. **Permission Errors**
   - Solution: Init container sets proper ownership (UID 1000)
   
3. **Storage Issues**
   - Solution: Pre-provision PVCs, verify storage class

4. **SSL Certificate Issues**
   - Solution: Manual cert-manager certificate request if needed

5. **Performance Issues**
   - Solution: Horizontal pod autoscaling, resource adjustment

## Success Criteria

### Technical Metrics
- ✅ 100% pod health
- ✅ < 2s page load time
- ✅ 99.9% uptime target
- ✅ Successful backup/restore test
- ✅ All API endpoints functional

### Business Metrics
- ✅ CRM accessible at quotennica.com
- ✅ Admin can create/manage records
- ✅ Email integration working
- ✅ API accessible for integrations
- ✅ Mobile responsive interface

## Rollback Plan

### Automated Rollback
```bash
# GitHub Actions handles automatic rollback on failure
# Manual rollback if needed:
kubectl rollout undo deployment/espocrm -n espocrm
kubectl rollout undo statefulset/espocrm-mysql -n espocrm
```

### Data Recovery
```bash
# Restore from backup
kubectl exec -i espocrm-mysql-0 -n espocrm -- mysql -u root -p < backup.sql
kubectl cp backup-files/ espocrm-pod:/var/www/html/data/
```

## Timeline

| Phase | Duration | Start Time | End Time |
|-------|----------|------------|----------|
| Repository Setup | 10 mins | T+0 | T+10 |
| Manifest Config | 20 mins | T+10 | T+30 |
| CI/CD Setup | 15 mins | T+30 | T+45 |
| Deployment | 30 mins | T+45 | T+75 |
| Validation | 20 mins | T+75 | T+95 |
| Monitoring | 15 mins | T+95 | T+110 |

**Total Time: ~2 hours**

## Next Steps
1. Execute Phase 1: Repository Setup
2. Finalize k3s manifests with production values
3. Test deployment in staging namespace first
4. Execute production deployment
5. Validate all checkpoints
6. Document any deviations or improvements