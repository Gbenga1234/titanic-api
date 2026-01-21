# Titanic API: Flask

Implemented using [Flask][] microframework.

## CI/CD Pipeline

This project uses GitHub Actions for automated CI/CD. See [.github/README.md](.github/README.md) for details.

## Installation and Launching

### Prerequisites

- Docker and Docker Compose installed
- For non-sudo Docker access: User added to `docker` group (log out and back in after `sudo usermod -aG docker $USER`)

### Clone

Clone the repo:

```bash
git clone https://github.com/PipeOpsHQ/titanic-api.git
cd titanic-api
```

### Development Environment

To run in development mode with hot-reload:

```bash
docker-compose -f docker-compose.dev.yml up --build
```

- App runs on <http://localhost:5000>
- Hot-reload enabled via volume mounting
- Database persists data in named volume

### Production Environment

To run in production mode:

```bash
docker-compose up --build
```

- Optimized multi-stage build (< 200MB image)
- Non-root user for security
- Health checks included

### Manual Testing

Once running, test the API:

1. Check empty database: `curl http://localhost:5000/people`
2. Add a passenger: `curl -H "Content-Type: application/json" -X POST localhost:5000/people -d'{"survived": 0,"passengerClass": 1,"name": "Test Passenger","sex": "male","age": 25.0,"siblingsOrSpousesAboard": 0,"parentsOrChildrenAboard": 0,"fare": 10.0}'`
3. Verify addition: `curl http://localhost:5000/people`

### Architecture

- **Multi-stage Dockerfile**: Builder stage for dependencies, runtime stage for execution
- **Security**: Non-root user, minimal base image
- **Database**: PostgreSQL with automatic initialization
- **Networking**: Isolated Docker network
- **Persistence**: Named volumes for data

[Flask]: http://flask.pocoo.org/
