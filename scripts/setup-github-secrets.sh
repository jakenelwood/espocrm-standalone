#!/bin/bash

# GitHub Secrets Setup Script for EspoCRM Deployment
# This script helps configure the required GitHub secrets for CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "   GitHub Secrets Setup for EspoCRM Deployment   "
echo "=================================================="
echo ""

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI is not authenticated${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}⚠️  kubectl is not installed (optional for validation)${NC}"
        KUBECTL_AVAILABLE=false
    else
        KUBECTL_AVAILABLE=true
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
    echo ""
}

# Get repository info
get_repo_info() {
    echo "Detecting repository..."
    
    # Try to get repo from current directory
    if [ -d .git ]; then
        REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")
    fi
    
    # If not in a git repo or couldn't detect, ask user
    if [ -z "$REPO" ]; then
        echo "Enter the GitHub repository (format: owner/repo):"
        read -r REPO
    else
        echo "Detected repository: $REPO"
        echo "Is this correct? (y/n)"
        read -r CONFIRM
        if [ "$CONFIRM" != "y" ]; then
            echo "Enter the correct GitHub repository (format: owner/repo):"
            read -r REPO
        fi
    fi
    
    # Verify repository exists
    if ! gh repo view "$REPO" &> /dev/null; then
        echo -e "${RED}❌ Repository $REPO not found or not accessible${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Repository verified: $REPO${NC}"
    echo ""
}

# Find kubeconfig file
find_kubeconfig() {
    echo "Looking for kubeconfig file..."
    
    # Common locations to check
    KUBECONFIG_PATHS=(
        "/home/brian/Dev/consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml"
        "$HOME/.kube/config"
        "$HOME/.kube/config-ai-consigliere"
        "./kubeconfig.yaml"
        "../consigliere-dev-pack/ai-consigliere-dev_kubeconfig.yaml"
    )
    
    KUBECONFIG_FILE=""
    for path in "${KUBECONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            echo "Found kubeconfig at: $path"
            KUBECONFIG_FILE="$path"
            break
        fi
    done
    
    # If not found, ask user
    if [ -z "$KUBECONFIG_FILE" ]; then
        echo -e "${YELLOW}Could not find kubeconfig automatically${NC}"
        echo "Enter the full path to your kubeconfig file:"
        read -r KUBECONFIG_FILE
        
        if [ ! -f "$KUBECONFIG_FILE" ]; then
            echo -e "${RED}❌ File not found: $KUBECONFIG_FILE${NC}"
            exit 1
        fi
    fi
    
    # Validate kubeconfig
    if ! grep -q "apiVersion:" "$KUBECONFIG_FILE"; then
        echo -e "${RED}❌ File doesn't appear to be a valid kubeconfig${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Using kubeconfig: $KUBECONFIG_FILE${NC}"
    
    # Optional: Test kubeconfig
    if [ "$KUBECTL_AVAILABLE" = true ]; then
        echo "Testing kubeconfig..."
        if kubectl --kubeconfig="$KUBECONFIG_FILE" cluster-info &> /dev/null; then
            echo -e "${GREEN}✅ Kubeconfig is valid and cluster is reachable${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not connect to cluster (may be network restricted)${NC}"
        fi
    fi
    
    echo ""
}

# Check existing secrets
check_existing_secrets() {
    echo "Checking existing secrets in $REPO..."
    
    # Get list of secrets (only names, not values)
    EXISTING_SECRETS=$(gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' || echo "")
    
    if echo "$EXISTING_SECRETS" | grep -q "KUBECONFIG_PRODUCTION"; then
        echo -e "${YELLOW}⚠️  KUBECONFIG_PRODUCTION already exists${NC}"
        echo "Do you want to update it? (y/n)"
        read -r UPDATE_SECRET
        if [ "$UPDATE_SECRET" != "y" ]; then
            echo "Skipping KUBECONFIG_PRODUCTION"
            return 0
        fi
    fi
    
    return 1
}

# Create or update secret
set_secret() {
    local SECRET_NAME=$1
    local SECRET_VALUE=$2
    
    echo "Setting secret: $SECRET_NAME..."
    
    if echo "$SECRET_VALUE" | gh secret set "$SECRET_NAME" --repo "$REPO" --body - ; then
        echo -e "${GREEN}✅ Secret $SECRET_NAME successfully set${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to set secret $SECRET_NAME${NC}"
        return 1
    fi
}

# Main setup process
main() {
    check_prerequisites
    get_repo_info
    find_kubeconfig
    
    # Check if we should update existing secrets
    SKIP_KUBECONFIG=false
    if check_existing_secrets; then
        SKIP_KUBECONFIG=true
    fi
    
    echo "=================================================="
    echo "Ready to configure secrets for: $REPO"
    echo "=================================================="
    echo ""
    
    # Set KUBECONFIG_PRODUCTION
    if [ "$SKIP_KUBECONFIG" = false ]; then
        echo "Encoding kubeconfig..."
        KUBECONFIG_BASE64=$(base64 -w0 < "$KUBECONFIG_FILE")
        
        if [ -z "$KUBECONFIG_BASE64" ]; then
            echo -e "${RED}❌ Failed to encode kubeconfig${NC}"
            exit 1
        fi
        
        echo "Setting KUBECONFIG_PRODUCTION secret..."
        if set_secret "KUBECONFIG_PRODUCTION" "$KUBECONFIG_BASE64"; then
            echo -e "${GREEN}✅ KUBECONFIG_PRODUCTION configured successfully!${NC}"
        else
            echo -e "${RED}❌ Failed to set KUBECONFIG_PRODUCTION${NC}"
            exit 1
        fi
    fi
    
    echo ""
    echo "=================================================="
    echo "                Setup Complete!                   "
    echo "=================================================="
    echo ""
    echo "Next steps:"
    echo "1. Verify secrets are configured:"
    echo "   gh workflow run validate-secrets.yml --repo $REPO"
    echo ""
    echo "2. Trigger a deployment:"
    echo "   git push origin main"
    echo ""
    echo "3. Monitor the deployment:"
    echo "   gh run watch --repo $REPO"
    echo ""
    echo "Secret management URL:"
    echo "https://github.com/$REPO/settings/secrets/actions"
    echo ""
    
    # Offer to run validation
    echo "Would you like to run the secret validation workflow now? (y/n)"
    read -r RUN_VALIDATION
    if [ "$RUN_VALIDATION" = "y" ]; then
        echo "Running validation workflow..."
        if gh workflow run validate-secrets.yml --repo "$REPO"; then
            echo -e "${GREEN}✅ Validation workflow started${NC}"
            echo "Watch it at: https://github.com/$REPO/actions"
        else
            echo -e "${YELLOW}⚠️  Could not start validation workflow${NC}"
            echo "The workflow file may not be pushed yet. Push your changes and try again."
        fi
    fi
}

# Run main function
main