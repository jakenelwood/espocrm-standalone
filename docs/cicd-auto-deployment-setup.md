# CI/CD Auto-Deployment Setup

**Date:** 2025-08-29  
**Status:** Configuration Complete - Awaiting Secret Setup

## ⚠️ REQUIRED: GitHub Secret Configuration

**The deployment will NOT work without this step!**

### Quick Setup (Recommended)
```bash
# Run the automated setup script:
./scripts/setup-github-secrets.sh
```

### Manual Setup
1. Generate the secret value:
   ```bash
   base64 -w0 /home/brian/Dev/consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml
   ```

2. Add to GitHub:
   - Go to: https://github.com/jakenelwood/espocrm-standalone/settings/secrets/actions
   - Click "New repository secret"
   - Name: `KUBECONFIG_PRODUCTION`
   - Value: [paste the base64 output]

3. Verify configuration:
   ```bash
   gh workflow run validate-secrets.yml --repo jakenelwood/espocrm-standalone
   ```

## Overview

The EspoCRM deployment pipeline has been configured for automatic deployment to production when code is pushed to the `main` branch. This integrates with the existing k3s cluster managed by the `consigliere-dev-pack` infrastructure.

## Changes Made

### 1. Workflow Modifications (`/.github/workflows/deploy.yml`)

#### Removed Staging Dependency
- **Before:** Production deployment required staging deployment to complete first
- **After:** Production deploys directly after successful build and test

```yaml
# Old
needs: [build-and-test, deploy-staging]

# New  
needs: build-and-test
```

#### Simplified Trigger Condition
- **Before:** Complex conditions with manual workflow dispatch
- **After:** Simple push to main branch triggers deployment

```yaml
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

#### Improved Deployment Process
- Added connection verification before deployment
- Better error handling for existing resources
- Smart MySQL deployment (skip if already running)
- Clearer logging and status updates

### 2. Image Push Optimization
- Fixed to push primary tag first
- Then pushes additional tags
- Prevents failures from multiline tag strings

## Required GitHub Secret

### ⚠️ ACTION REQUIRED

You must add the following secret to enable auto-deployment:

1. **Navigate to GitHub Secrets:**
   ```
   https://github.com/jakenelwood/espocrm-standalone/settings/secrets/actions
   ```

2. **Add New Repository Secret:**
   - **Name:** `KUBECONFIG_PRODUCTION`
   - **Value:** Base64 encoded kubeconfig

3. **Get the Secret Value:**
   ```bash
   # Run this command locally to get the base64 encoded kubeconfig:
   base64 -w0 < /home/brian/Dev/consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml
   ```

4. **Copy the entire output** and paste it as the secret value

## Deployment Flow

```mermaid
graph LR
    A[Push to main] --> B[Validate Manifests]
    B --> C[Build & Test]
    C --> D[Trivy Security Scan]
    D --> E[Push to Registry]
    E --> F[Deploy to Production]
    F --> G[Health Checks]
```

### Step Details

1. **Validate Manifests** - Checks YAML syntax and Kubernetes compatibility
2. **Build & Test** - Builds Docker image and runs application tests
3. **Security Scan** - Trivy scans for vulnerabilities (CRITICAL/HIGH)
4. **Push to Registry** - Pushes to GitHub Container Registry (ghcr.io)
5. **Deploy to Production** - Updates k3s cluster with new image
6. **Health Checks** - Verifies deployment is healthy

## Deployment Targets

- **Namespace:** `espocrm`
- **URL:** https://quotennica.com
- **Cluster:** ai-consigliere-dev (Hetzner k3s)
- **Load Balancer:** 5.161.35.135

## Resources Deployed

1. **MySQL StatefulSet** - Database backend
2. **EspoCRM Deployment** - Main application
3. **Service** - ClusterIP service
4. **Ingress** - NGINX ingress for external access
5. **ConfigMap** - Application configuration
6. **PersistentVolumeClaim** - Data storage

## Testing the Pipeline

After adding the secret:

1. **Make a test change:**
   ```bash
   echo "# Test deployment $(date)" >> README.md
   git add README.md
   git commit -m "test: Auto-deployment pipeline"
   git push origin main
   ```

2. **Monitor the deployment:**
   ```bash
   # Watch GitHub Actions
   gh run watch --repo jakenelwood/espocrm-standalone
   
   # Check cluster status
   kubectl get pods -n espocrm
   kubectl logs -f deployment/espocrm -n espocrm
   ```

3. **Verify application:**
   ```bash
   curl -I https://quotennica.com
   ```

## Rollback Procedure

If deployment fails or causes issues:

```bash
# Get previous image
kubectl rollout history deployment/espocrm -n espocrm

# Rollback to previous version
kubectl rollout undo deployment/espocrm -n espocrm

# Or rollback to specific revision
kubectl rollout undo deployment/espocrm -n espocrm --to-revision=2
```

## Monitoring

### GitHub Actions
- View runs: https://github.com/jakenelwood/espocrm-standalone/actions
- Failed runs will show which step failed
- Logs available for each step

### Cluster Monitoring
```bash
# Pod status
kubectl get pods -n espocrm -w

# Deployment status
kubectl describe deployment/espocrm -n espocrm

# Recent events
kubectl get events -n espocrm --sort-by='.lastTimestamp'

# Application logs
kubectl logs -f deployment/espocrm -n espocrm
```

## Troubleshooting

### Secret Not Working
1. Ensure secret name is exactly `KUBECONFIG_PRODUCTION`
2. Verify base64 encoding (no line breaks)
3. Check secret is added to repository, not organization

### Deployment Fails
1. Check GitHub Actions logs for specific error
2. Verify kubeconfig is valid: `kubectl --kubeconfig=<file> get nodes`
3. Ensure cluster is accessible from GitHub Actions runners

### Application Not Accessible
1. Check ingress status: `kubectl get ingress -n espocrm`
2. Verify DNS points to load balancer: `nslookup quotennica.com`
3. Check certificate status if using HTTPS

## Next Steps

1. ✅ Workflow configuration complete
2. ⏳ Add `KUBECONFIG_PRODUCTION` secret to GitHub
3. ⏳ Test deployment with a commit to main
4. ⏳ Verify application is accessible at https://quotennica.com

## Integration with consigliere-dev-pack

This deployment integrates with the broader infrastructure managed by `consigliere-dev-pack`:

- Uses the same k3s cluster
- Shares the load balancer with other applications
- Follows the same GitOps principles
- Compatible with existing monitoring and logging

## Security Considerations

- Kubeconfig is stored as encrypted GitHub secret
- Only main branch triggers production deployment
- Trivy scanning blocks deployment of vulnerable images
- Pod security standards enforced by k3s
- Network policies restrict pod communication

---

*Configuration by: DevOps Team*  
*Date: 2025-08-29*