# Running Titanic API Locally with Docker

Complete guide to pulling and running the Titanic API Docker image on your local machine.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Setup](#detailed-setup)
4. [Running the Docker Image](#running-the-docker-image)
5. [Using Docker Compose](#using-docker-compose)
6. [Configuration](#configuration)
7. [Accessing the Application](#accessing-the-application)
8. [Stopping and Cleaning Up](#stopping-and-cleaning-up)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker**: [Install Docker Desktop](https://www.docker.com/products/docker-desktop) (includes Docker Engine and Docker CLI)
- **Docker Compose** (optional but recommended): Usually included with Docker Desktop

### Verify Installation

Check that Docker is installed and working:

```bash
# Check Docker version
docker --version

# Check Docker Compose (if installed)
docker-compose --version

# Verify Docker daemon is running (test by pulling a small image)
docker run hello-world
```

### System Requirements

- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum (8GB recommended for comfortable development)
- **Disk Space**: 2GB free minimum
- **Network**: Internet access to pull images

### Optional: Non-sudo Docker Access (Linux/macOS)

To run Docker commands without `sudo`:

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (no need to logout/login in newer systems)
newgrp docker

# Verify access
docker ps
```

---

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/PipeOpsHQ/titanic-api.git
cd titanic-api

# Start the application with database
docker-compose up --build

# App will be available at http://localhost:5000
```

### Option 2: Build and Run Manually

```bash
# Build the image
docker build -t titanic-api:latest .

# Create and run the container
docker run -p 5000:5000 titanic-api:latest

# App will be available at http://localhost:5000
```

---

## Detailed Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/PipeOpsHQ/titanic-api.git
cd titanic-api
```

### Step 2: Build the Docker Image

#### From Dockerfile (includes build step)

```bash
docker build -t titanic-api:latest .
```

**Options:**
- `-t titanic-api:latest` - Tag the image with a name
- `--no-cache` - Force rebuild without using cached layers
- `-f Dockerfile` - Explicitly specify Dockerfile path

```bash
# Example: Build without cache
docker build --no-cache -t titanic-api:latest .

# Example: Build with version tag
docker build -t titanic-api:v1.0.0 .
```

#### Pull from Registry (if available)

```bash
# Once published to Docker Hub or your registry
docker pull yourusername/titanic-api:latest
```

### Step 3: Verify the Image

```bash
# List images
docker images | grep titanic-api

# Inspect image details
docker inspect titanic-api:latest
```

---

## Running the Docker Image

### Standalone (Without Database)

**Note:** App will fail to start without database. Use this only for testing the image.

```bash
docker run -p 5000:5000 titanic-api:latest
```

### With External PostgreSQL

If you have PostgreSQL running elsewhere:

```bash
docker run \
  -p 5000:5000 \
  -e DATABASE_URL=postgresql+psycopg2://user:password@host:5432/dbname \
  -e FLASK_ENV=production \
  titanic-api:latest
```

**Environment Variables:**
- `DATABASE_URL` - PostgreSQL connection string
- `FLASK_ENV` - `development` or `production`

### Interactive Mode (with Terminal)

```bash
# Run and keep terminal open
docker run -it -p 5000:5000 titanic-api:latest

# Press Ctrl+C to stop
```

### Detached Mode (Background)

```bash
# Run in background
docker run -d -p 5000:5000 --name titanic-api titanic-api:latest

# View logs
docker logs titanic-api

# Follow logs in real-time
docker logs -f titanic-api

# Stop the container
docker stop titanic-api

# Start it again
docker start titanic-api

# Remove the container
docker rm titanic-api
```

---

## Using Docker Compose

### Production Setup

```bash
# Start with database (production config)
docker-compose up --build

# Detached mode (background)
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes (reset database)
docker-compose down -v
```

### Development Setup (Hot Reload)

```bash
# Start in development mode with hot-reload
docker-compose -f docker-compose.dev.yml up --build

# Detached mode
docker-compose -f docker-compose.dev.yml up -d --build

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Useful Docker Compose Commands

```bash
# List running services
docker-compose ps

# Execute command in running container
docker-compose exec app python -c "import flask; print(flask.__version__)"

# Rebuild images without starting
docker-compose build

# Rebuild specific service
docker-compose build app

# Pull latest images
docker-compose pull

# View resource usage
docker stats

# Validate docker-compose.yml syntax
docker-compose config

# View service logs for specific service
docker-compose logs app
docker-compose logs db
```

---

## Configuration

### Environment Variables

Set these when running the container:

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLASK_ENV` | `production` | Environment mode (`development`, `production`, `testing`) |
| `DATABASE_URL` | See below | PostgreSQL connection string |
| `PORT` | `5000` | Port the application listens on |

### Database Connection String Format

```
postgresql+psycopg2://username:password@host:port/database
postgresql+psycopg2://user:password@db:5432/postgres
```

### Running with Custom Environment Variables

#### Using `-e` flag:

```bash
docker run -p 5000:5000 \
  -e FLASK_ENV=development \
  -e DATABASE_URL=postgresql+psycopg2://user:password@localhost:5432/titanic \
  titanic-api:latest
```

#### Using `.env` file (Docker Compose):

Create `.env` in project root:

```env
FLASK_ENV=production
DATABASE_URL=postgresql+psycopg2://user:password@db:5432/postgres
PORT=5000
```

Then run:

```bash
docker-compose up --build
```

Docker Compose automatically loads `.env` file.

### Volume Mounts (Development)

Mount source code for hot-reload:

```bash
docker run -p 5000:5000 \
  -v $(pwd)/src:/home/app/src \
  -e FLASK_ENV=development \
  titanic-api:latest
```

Or with Docker Compose (already configured in `docker-compose.dev.yml`):

```bash
docker-compose -f docker-compose.dev.yml up --build
```

---

## Accessing the Application

### Base URL

```
http://localhost:5000
```

### Health Check

```bash
curl http://localhost:5000/health/live
```

### API Endpoints

#### Get all people
```bash
curl http://localhost:5000/people
```

#### Get specific person
```bash
curl http://localhost:5000/people/{id}
```

#### Create new person
```bash
curl -X POST http://localhost:5000/people \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "age": 30,
    "passengerClass": 1,
    "survived": true
  }'
```

#### Update person
```bash
curl -X PUT http://localhost:5000/people/{id} \
  -H "Content-Type: application/json" \
  -d '{"age": 31}'
```

#### Delete person
```bash
curl -X DELETE http://localhost:5000/people/{id}
```

### Metrics Endpoint (if instrumented)

```bash
curl http://localhost:5000/metrics
```

### View in Browser

Simply open: http://localhost:5000

---

## Stopping and Cleaning Up

### Stop Containers

#### Docker Compose:

```bash
# Stop services (keeps data)
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop, remove containers, and delete volumes (wipes database)
docker-compose down -v
```

#### Standalone Docker:

```bash
# Stop running container
docker stop <container_id_or_name>

# Remove stopped container
docker rm <container_id_or_name>

# List all containers (including stopped)
docker ps -a
```

### Clean Up Disk Space

```bash
# Remove stopped containers
docker container prune

# Remove dangling images
docker image prune

# Remove unused images
docker image prune -a

# Remove all stopped containers, dangling images, unused networks, and unused volumes
docker system prune -a --volumes

# Check disk usage
docker system df
```

### Reset Everything (Development)

```bash
# Remove all containers, images, and volumes (WARNING: deletes data)
docker-compose down -v
docker system prune -a --volumes

# Rebuild and start fresh
docker-compose build --no-cache
docker-compose up
```

---

## Troubleshooting

### Port Already in Use

**Error:** `Address already in use`

**Solution:** Use a different port:

```bash
# Run on port 8000 instead
docker run -p 8000:5000 titanic-api:latest

# Access at http://localhost:8000
```

Or kill the process using port 5000:

```bash
# Linux/macOS
lsof -i :5000
kill -9 <PID>

# Windows (PowerShell)
netstat -ano | findstr :5000
taskkill /PID <PID> /F
```

### Database Connection Error

**Error:** `Connection refused` or `could not connect to database`

**Causes:**
1. PostgreSQL container not running
2. Wrong connection string
3. Database not initialized

**Solutions:**

```bash
# Check if database is healthy
docker-compose ps

# View database logs
docker-compose logs db

# Recreate database
docker-compose down -v
docker-compose up --build

# Check DATABASE_URL environment variable
docker-compose config | grep DATABASE_URL
```

### Container Exits Immediately

**Error:** Container starts then stops

**Solutions:**

```bash
# View container logs
docker logs <container_id>

# Run with interactive terminal to see errors
docker run -it titanic-api:latest

# Check if database is ready
docker-compose logs db
```

### Docker Daemon Not Running

**Error:** `Cannot connect to Docker daemon`

**Solution:**
- Start Docker Desktop application
- On Linux: `sudo systemctl start docker`

### Out of Disk Space

**Error:** `no space left on device`

**Solution:**

```bash
# Remove unused images and containers
docker system prune -a --volumes

# Check disk usage
docker system df
```

### Permission Denied Errors

**Error:** `Permission denied while trying to connect to Docker daemon`

**Solution (Linux):**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
```

### Slow Database on Docker

**Issue:** Slow queries or timeouts

**Solution:**

1. Check Docker resource allocation (Docker Desktop settings)
2. Increase memory allocated to Docker
3. Check if database is still initializing

```bash
# Wait for database to be healthy
docker-compose ps

# Check DB logs
docker-compose logs db
```

### Hot-Reload Not Working

**Issue:** Code changes not reflected in running container

**Solution:**

1. Use `docker-compose.dev.yml` instead of `docker-compose.yml`
2. Ensure volume mounts are correct
3. Check file system events are enabled

```bash
# Stop and rebuild
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up --build
```

### Networking Issues (Multiple Containers)

**Error:** Containers can't communicate with each other

**Solution:**

1. Ensure containers are on same network:

```bash
# View networks
docker network ls

# Inspect network
docker network inspect titanic

# Docker Compose automatically creates network, verify with:
docker-compose ps
```

2. Use service name (not IP) when containers talk to each other:

```
# Good (service name)
DATABASE_URL=postgresql://db:5432/postgres

# Bad (IP - won't persist)
DATABASE_URL=postgresql://172.18.0.2:5432/postgres
```

---

## Common Workflows

### Development Workflow

```bash
# 1. Start with hot-reload
docker-compose -f docker-compose.dev.yml up --build

# 2. Edit code in your editor
# Changes auto-reload in container

# 3. View logs
docker-compose logs -f app

# 4. Test API
curl http://localhost:5000/people

# 5. Stop when done
docker-compose down
```

### Testing Before Deployment

```bash
# 1. Build production image
docker build -t titanic-api:test .

# 2. Run with production database
docker run -p 5000:5000 \
  -e FLASK_ENV=production \
  -e DATABASE_URL=postgresql+psycopg2://user:password@db:5432/postgres \
  titanic-api:test

# 3. Test endpoints
curl http://localhost:5000/health/live
curl http://localhost:5000/people

# 4. Check logs
docker logs <container_id>
```

### Multiple Environments

```bash
# Development
docker-compose -f docker-compose.dev.yml up --build

# Production
docker-compose -f docker-compose.yml up --build

# Custom config
docker-compose -f docker-compose.custom.yml up --build
```

---

## Best Practices

✅ **Do:**
- Use Docker Compose for multi-container setups
- Tag images with version numbers
- Use `.env` file for secrets in development only
- Keep container logs for debugging
- Use health checks
- Set resource limits

❌ **Don't:**
- Run containers as root
- Put secrets directly in Dockerfile
- Use `latest` tag in production (use specific versions)
- Mount entire source directory if not needed
- Run multiple versions of same app without different ports

---

## Reference

### Useful Docker Commands

```bash
# View images
docker images

# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# View container logs
docker logs <container_id>

# Execute command in container
docker exec -it <container_id> bash

# Stop container
docker stop <container_id>

# Remove container
docker rm <container_id>

# Remove image
docker rmi <image_id>

# Build image
docker build -t <name>:<tag> .

# Run container
docker run -p <host_port>:<container_port> <image>
```

### Useful Docker Compose Commands

```bash
# Start services
docker-compose up

# Start in background
docker-compose up -d

# Stop services
docker-compose down

# View service status
docker-compose ps

# View logs
docker-compose logs -f

# Rebuild images
docker-compose build

# Execute command
docker-compose exec <service> <command>

# Validate syntax
docker-compose config
```

---

## Next Steps

1. **Review Monitoring** → Check [monitoring/README.md](monitoring/README.md) for observability setup
2. **Kubernetes Deployment** → See [README_K8S.md](README_K8S.md) for K8s deployment
3. **CI/CD Pipeline** → Check [.github/README.md](.github/README.md) for GitHub Actions
4. **API Documentation** → Test endpoints after starting container

---

## Support

- **Docker Documentation**: https://docs.docker.com
- **Docker Desktop Troubleshooting**: https://docs.docker.com/desktop/troubleshoot/
- **Flask Documentation**: https://flask.palletsprojects.com/
- **PostgreSQL in Docker**: https://hub.docker.com/_/postgres

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-22 | Initial guide for local Docker setup |

