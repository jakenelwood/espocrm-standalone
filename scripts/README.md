# Scripts Directory

This directory contains automation scripts for managing the EspoCRM deployment pipeline.

## 🚀 Quick Start

### First-Time Setup
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Configure GitHub secrets for deployment
./scripts/setup-github-secrets.sh
```

## Available Scripts

### setup-github-secrets.sh

**Purpose:** Automatically configures required GitHub secrets for CI/CD deployment

**What it does:**
- Detects your GitHub repository
- Finds your kubeconfig file
- Validates the configuration
- Sets up the KUBECONFIG_PRODUCTION secret
- Optionally runs validation

**Usage:**
```bash
./scripts/setup-github-secrets.sh
```

**Prerequisites:**
- GitHub CLI (`gh`) installed and authenticated
- Access to the repository settings
- Valid kubeconfig file for the k3s cluster

**Interactive prompts:**
1. Confirms detected repository (or asks for input)
2. Confirms kubeconfig location (or asks for path)
3. Asks to update existing secrets if found
4. Offers to run validation workflow

## Manual Secret Configuration

If you prefer to set up secrets manually:

### 1. Generate the Base64 Encoded Secret
```bash
# Encode your kubeconfig file
base64 -w0 /home/brian/Dev/consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml
```

### 2. Add to GitHub
1. Navigate to: https://github.com/jakenelwood/espocrm-standalone/settings/secrets/actions
2. Click "New repository secret"
3. Enter:
   - Name: `KUBECONFIG_PRODUCTION`
   - Value: [paste the base64 string]
4. Click "Add secret"

### 3. Validate Configuration
```bash
# Run the validation workflow
gh workflow run validate-secrets.yml --repo jakenelwood/espocrm-standalone

# Check the results
gh run list --repo jakenelwood/espocrm-standalone --workflow validate-secrets.yml
```

## Troubleshooting

### Script Issues

**"GitHub CLI (gh) is not installed"**
- Install from: https://cli.github.com/
- Debian/Ubuntu: `sudo apt install gh`
- macOS: `brew install gh`

**"GitHub CLI is not authenticated"**
```bash
gh auth login
```

**"Repository not found or not accessible"**
- Ensure you have admin access to the repository
- Check repository name format: `owner/repo`

**"Could not find kubeconfig automatically"**
- Manually specify the path when prompted
- Common locations:
  - `/home/brian/Dev/consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml`
  - `~/.kube/config`
  - `~/.kube/config-ai-consigliere`

### Secret Validation Issues

**"KUBECONFIG_PRODUCTION is not valid base64"**
- Ensure you used `-w0` flag: `base64 -w0 < file`
- This prevents line wrapping in the encoded output

**"Could not connect to cluster"**
- This is normal from GitHub Actions if the cluster is not publicly accessible
- The kubeconfig is still valid, just not reachable from GitHub's network

## Related Documentation

- [CI/CD Setup Guide](../docs/cicd-auto-deployment-setup.md)
- [Deployment Failure Fix](../docs/deployment-failure-fix-kubeconfig-secret.md)
- [Workflow Files](../.github/workflows/)

## Security Notes

⚠️ **Important Security Considerations:**

1. **Never commit secrets to the repository**
   - Kubeconfig files contain sensitive cluster access credentials
   - Always use GitHub Secrets for sensitive data

2. **Limit secret access**
   - Only repository admins can view/modify secrets
   - Use GitHub Environments for additional access control

3. **Rotate credentials regularly**
   - Update kubeconfig if cluster credentials change
   - Re-run the setup script to update secrets

4. **Audit secret usage**
   - Check workflow runs to see when secrets are accessed
   - Monitor for unauthorized workflow modifications

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review the workflow logs: https://github.com/jakenelwood/espocrm-standalone/actions
3. Ensure all prerequisites are installed
4. Verify repository permissions

---

*Last updated: 2025-08-29*