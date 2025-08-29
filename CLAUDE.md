# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a standalone deployment of EspoCRM designed for k3s clusters. It's a complete CRM solution with MySQL database, automated CI/CD, and comprehensive monitoring. The project consists of:

- **EspoCRM PHP Application**: Core CRM system located in `/application/Espo/`
- **k3s Deployment Manifests**: Kubernetes configuration in `/k3s/`
- **Docker Setup**: Containerization with PHP 8.1 and Apache
- **CI/CD Pipeline**: GitHub Actions workflow for automated deployment

## Key Commands

### Local Development
```bash
# Build Docker image locally
docker build -t espocrm-standalone .

# Run locally with Docker Compose
docker-compose up

# Clear EspoCRM cache
php clear_cache.php

# Rebuild application
php rebuild.php

# Run cron jobs
php cron.php

# Execute console commands
php command.php <command-name>
```

### k3s Deployment
```bash
# Deploy to k3s cluster
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/rbac.yaml
kubectl apply -f k3s/mysql/
kubectl apply -f k3s/configmap.yaml
kubectl apply -f k3s/secrets.yaml  # Create from secrets.example.yaml first
kubectl apply -f k3s/pvc.yaml
kubectl apply -f k3s/service.yaml
kubectl apply -f k3s/deployment.yaml
kubectl apply -f k3s/ingress.yaml

# Check deployment status
kubectl get pods -n espocrm
kubectl logs -f deployment/espocrm -n espocrm

# Access MySQL database
kubectl exec -it espocrm-mysql-0 -n espocrm -- mysql -u root -p

# Clear cache in k3s
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/clear_cache.php

# Rebuild in k3s
kubectl exec -n espocrm deployment/espocrm -- php /var/www/html/rebuild.php
```

### Backup & Restore
```bash
# Backup database
kubectl exec -n espocrm espocrm-mysql-0 -- mysqldump -u root -p espocrm > backup.sql

# Restore database
kubectl exec -i -n espocrm espocrm-mysql-0 -- mysql -u root -p espocrm < backup.sql
```

## High-Level Architecture

### Application Structure
The EspoCRM application follows a modular MVC architecture:

```
/application/Espo/
├── Core/           # Core framework components
│   ├── Application.php        # Main application entry point
│   ├── Container/             # Dependency injection container
│   ├── Api/                   # API request/response handling
│   ├── ORM/                   # Object-Relational Mapping layer
│   └── Controllers/           # Base controller classes
├── Controllers/    # HTTP request controllers
├── Entities/       # Domain entities (ORM models)
├── Repositories/   # Data access layer
├── Services/       # Business logic layer
├── Classes/        # Utility and helper classes
├── Hooks/          # Event hooks and listeners
└── Modules/        # Additional CRM modules

/client/            # Frontend JavaScript application
├── lib/            # Compiled JavaScript bundles
├── css/            # Stylesheets
└── modules/        # Frontend modules
```

### Deployment Architecture
The k3s deployment consists of:

1. **MySQL StatefulSet**: Persistent database with 20Gi storage
2. **EspoCRM Deployment**: Scalable PHP application pods
3. **Persistent Volumes**: Application data (10Gi) for uploads/files
4. **Ingress**: NGINX ingress controller with SSL/TLS
5. **Network Policies**: Security-first network isolation
6. **RBAC**: Role-based access control for service accounts

### Request Flow
1. External request → Ingress Controller
2. Ingress → EspoCRM Service (port 80)
3. Service → EspoCRM Pod(s)
4. PHP Application → MySQL Database
5. Background jobs via cron container

### Key Integration Points

- **API Endpoints**: RESTful API at `/api/v1/` for external integrations
- **Webhooks**: Outbound webhooks for event notifications
- **Email Integration**: IMAP/SMTP for email processing
- **Authentication**: Multiple auth methods (API key, Basic, HMAC)
- **File Storage**: Local persistent volume for attachments

### Security Considerations

- Runs as non-root user (UID 1000)
- Read-only root filesystem where possible
- Network policies restrict pod-to-pod communication
- Secrets stored in Kubernetes secrets
- Pod Security Standards enforced (restricted)

### Performance Optimization

- OPcache enabled for PHP
- Apache mod_deflate for compression
- Health checks and readiness probes
- Horizontal pod autoscaling supported
- Resource limits configured per pod

## Important Files

- `/application/Espo/Core/Application.php` - Main application entry point
- `/index.php` - Web entry point
- `/command.php` - CLI command runner
- `/cron.php` - Cron job processor
- `/clear_cache.php` - Cache clearing utility
- `/rebuild.php` - Application rebuild utility
- `/docker-entrypoint.sh` - Container initialization script
- `/k3s/deployment.yaml` - Main k3s deployment configuration
- `/.github/workflows/deploy.yml` - CI/CD pipeline definition

## Development Workflow

1. Make changes to PHP code in `/application/Espo/`
2. Clear cache: `php clear_cache.php`
3. Rebuild if needed: `php rebuild.php`
4. Test locally with Docker
5. Push to GitHub to trigger CI/CD
6. Deployment happens automatically to staging (develop branch) or production (main branch)

## Troubleshooting

When issues occur:
1. Check pod logs: `kubectl logs -f -l app=espocrm -n espocrm`
2. Check MySQL: `kubectl logs -f statefulset/espocrm-mysql -n espocrm`
3. Clear cache and rebuild application
4. Verify persistent volume mounts are working
5. Check ingress configuration for external access issues