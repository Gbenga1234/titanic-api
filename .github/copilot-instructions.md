# Titanic API - AI Agent Instructions

## Architecture Overview

This is a **Flask REST API** with PostgreSQL backend for Titanic passenger data, deployable across Docker, Kubernetes, and Azure via Terraform. Key pattern: **blueprint-based modular views** with SQLAlchemy ORM models.

```
src/app.py           (Flask factory, blueprint registration)
├── models/          (SQLAlchemy ORM - Person model with marshmallow schemas)
└── views/           (Blueprint endpoints - CRUD operations on /people)
```

## Core Patterns

### Model-View-Schema Layer
- **Models** ([src/models/person.py](src/models/person.py)): SQLAlchemy models with instance methods (`save()`, `update()`, `delete()`) + static query methods (`get_all()`, `get_by_id()`)
- **Schemas** (within models): Marshmallow schemas for serialization/deserialization (use `schema.dump()` to serialize, `schema.load()` to deserialize)
- **Views** ([src/views/people.py](src/views/people.py)): Flask Blueprints with routes returning `custom_response(data, status_code)`

### Environment Configuration
Three configs in [src/config.py](src/config.py): `Development` (DEBUG=True, SQLite in tests), `Production` (DEBUG=False), `Testing` (in-memory SQLite). Selected via `FLASK_ENV` env var.

### Database
PostgreSQL in production via `DATABASE_URL` env var. Tests use in-memory SQLite. Init scripts in [init.sql](init.sql).

## Development Workflows

### Quick Start
```bash
docker-compose -f docker-compose.dev.yml up --build  # Hot-reload dev
docker-compose up --build                             # Production-like
```
App runs on `http://localhost:5000`. Database auto-initializes with [init.sql](init.sql).

### Testing
```bash
pip install -r requirements.txt pytest pytest-cov flake8
pytest --cov=src                    # Run with coverage
flake8 src                          # Lint check
```
Tests use fixtures in [tests/test_app.py](tests/test_app.py) with `app` and `client` fixtures. Coverage target: 80% (see [pytest.ini](pytest.ini)).

### Adding New Endpoints
1. Add method to model class with business logic
2. Create route in views blueprint, call `schema.load()` for input, `schema.dump()` for response
3. Return `custom_response(data, status_code)`

## CI/CD & Deployment

### GitHub Actions
Runs on push to `main`: pytest, flake8, 80% coverage check, Trivy security scan, Docker build → Hub. See [.github/README.md](.github/README.md) for secrets setup.

### Docker
Multi-stage build ([Dockerfile](Dockerfile)): builder + runtime. Non-root user `app`. Health checks enabled. Optimized < 200MB.

### Kubernetes
Full manifests in [k8s/](k8s/) with kustomization. Key resources: StatefulSet for PostgreSQL, Deployment for Flask, LoadBalancer + Ingress, HPA (autoscale 2-5 pods). Rollout: `kubectl rollout status deployment/titanic-api -n titanic-api`.

### Terraform + Azure
[terraform/](terraform/) provisions AKS cluster, Azure Database PostgreSQL, VNet, and security controls. Environments split: [dev/](terraform/environments/dev/) and [prod/](terraform/environments/prod/). Modules in [modules/](terraform/modules/).

## Project Conventions

- **No generic error handling**: Use Flask's built-in error responses (e.g., 404 for missing persons)
- **Serialization pattern**: Always use schema objects, never manual JSON serialization
- **UUID primary keys**: Person model uses string UUIDs for cross-database compatibility
- **Field naming**: Matches Titanic dataset (e.g., `passengerClass`, `siblingsOrSpousesAboard`)
- **Duplicate column defs**: Note duplicate column definitions in person.py (technical debt—consolidate if adding fields)

## Key Files Reference

| File | Purpose |
|------|---------|
| [run.py](run.py) | Entry point; creates app with FLASK_ENV |
| [requirements.txt](requirements.txt) | Flask 2.0.1, SQLAlchemy, marshmallow, gunicorn |
| [docker-compose.yml](docker-compose.yml) | Production setup: app + PostgreSQL |
| [docker-compose.dev.yml](docker-compose.dev.yml) | Dev setup: volume mounts for hot-reload |
| [k8s/deployment-app.yaml](k8s/deployment-app.yaml) | Kubernetes Flask deployment |
| [k8s/statefulset-postgres.yaml](k8s/statefulset-postgres.yaml) | Kubernetes PostgreSQL stateful service |
| [terraform/main.tf](terraform/main.tf) | Azure AKS + database provisioning |

## External Dependencies

- **Database**: PostgreSQL 15 (health checks required)
- **ORM**: SQLAlchemy < 2.0 (schema not finalized for v2)
- **Serialization**: Marshmallow 3.12.2
- **WSGI**: Gunicorn 20.1.0 (production runs via [run.py](run.py))
- **Framework**: Flask 2.0.1 with blueprints

## Common Tasks for Agents

- **Add CRUD endpoint**: Model → Schema → Blueprint route → custom_response
- **Change database schema**: Update Person model fields, regenerate init.sql migrations
- **Debug failing test**: Check fixtures in test_app.py, verify in-memory SQLite schema matches
- **Deploy code**: Push to main → GitHub Actions handles Docker build + registry push
- **Scale infrastructure**: Modify HPA replicas in [k8s/hpa.yaml](k8s/hpa.yaml) or AKS node pool in Terraform

