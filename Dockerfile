FROM python:3.11-slim

# Install security updates + curl (for healthcheck)
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Create a non-root user with stable UID/GID (better for K8s)
RUN groupadd -g 1000 app && useradd -m -u 1000 -g 1000 -s /bin/bash app

WORKDIR /home/app

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

COPY . .

# Ensure non-root can read/write where needed
RUN chown -R app:app /home/app

USER app

EXPOSE 5000

# Safer: call curl from PATH, not absolute path
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:5000/ || exit 1

CMD ["python", "run.py"]
