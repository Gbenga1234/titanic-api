# Titanic API CI/CD Pipeline

This repository uses GitHub Actions for automated CI/CD.

## Pipeline Overview

The CI/CD pipeline includes the following stages:

### Continuous Integration (CI)
- **Automated Testing**: Unit tests using pytest
- **Linting**: Code quality checks with flake8
- **Code Coverage**: Coverage reporting with pytest-cov (80% threshold)
- **Security Scanning**: Container vulnerability scanning with Trivy

### Continuous Deployment (CD)
- **Docker Build & Push**: Automated build and push to Docker Hub
- **Deployment**: Placeholder for deployment to staging/production

## Setup

### GitHub Secrets Required
Add the following secrets to your GitHub repository:

- `DOCKERHUB_USERNAME`: Your Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token (not password)

### Local Development
```bash
# Run tests locally
pip install -r requirements.txt
pip install pytest pytest-cov flake8
pytest --cov=src

# Run linting
flake8 src
```

### Deployment
The deployment step is currently a placeholder. To implement actual deployment:

1. Choose a deployment target (AWS ECS, Heroku, DigitalOcean, etc.)
2. Update the `deploy` job in `.github/workflows/ci-cd.yml`
3. Add necessary secrets (SSH keys, API tokens, etc.)

Example for SSH deployment:
```yaml
- name: Deploy to server
  uses: appleboy/ssh-action@master
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    key: ${{ secrets.SERVER_SSH_KEY }}
    script: |
      docker pull ${{ secrets.DOCKERHUB_USERNAME }}/titanic-api:latest
      docker-compose down
      docker-compose up -d
```

## Workflow Triggers
- Push to `main` branch
- Pull requests to `main` branch

## Quality Gates
- All tests must pass
- Code coverage ≥ 80%
- No critical security vulnerabilities
- Linting passes

## Monitoring
- Test results and coverage reports
- Security scan results uploaded to GitHub Security tab
- Build artifacts and logs available in Actions