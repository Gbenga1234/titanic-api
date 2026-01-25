# 🚢 Titanic API – Local Development with Docker

Running Titanic API Locally with Docker

### A quick guide to running the Titanic API locally using Docker and Docker Compose.

### Prerequisites

Docker Desktop (includes Docker Compose)

Internet access (to pull images)

Verify:

docker --version
docker compose version
docker run hello-world


(Optional – Linux) Run Docker without sudo:

sudo usermod -aG docker $USER
newgrp docker

### Quick Start (Recommended)
Run with Docker Compose (App + PostgreSQL)
git clone https://github.com/Gbenga1234/titanic-api.git
cd titanic-api

docker compose up --build


### App runs at:

http://localhost:5000

# Development Mode (Hot Reload)
docker compose -f docker-compose.dev.yml up --build

# Run with Docker Only (External DB Required)
docker build -t titanic-api:latest .

docker run -p 5000:5000 \
  -e FLASK_ENV=production \
  -e DATABASE_URL=postgresql+psycopg2://user:password@host:5432/dbname \
  titanic-api:latest

###Configuration
Required Environment Variables
Variable	Description
DATABASE_URL	PostgreSQL connection string
FLASK_ENV	development or production

DB URL format

postgresql+psycopg2://user:password@db:5432/postgres


Docker Compose automatically loads .env if present.

Common Commands
# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Reset database
docker compose down -v

API Access

Base URL:

http://localhost:5000


Health check:

curl http://localhost:5000/health/live


Example:

curl http://localhost:5000/people
