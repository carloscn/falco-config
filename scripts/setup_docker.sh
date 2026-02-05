#!/usr/bin/env bash
# Docker Environment Setup Script
# Creates Ubuntu 22.04 container for Falco experiments

set -e

echo "=========================================="
echo "Falco IDPS Experimental Environment Setup"
echo "=========================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed, please install Docker first"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed, please install docker-compose first"
    exit 1
fi

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p falco-config
mkdir -p falco-logs

# Stop and remove old containers (if exist)
echo "Cleaning up old containers..."
docker-compose down 2>/dev/null || true

# Delete old container (by name)
if docker ps -a --format '{{.Names}}' | grep -q "^falco-test-ubuntu$"; then
    echo "Removing old container falco-test-ubuntu..."
    docker rm -f falco-test-ubuntu 2>/dev/null || true
fi

# Build and start container
echo "Building Docker image..."
docker-compose build

echo "Starting container..."
docker-compose up -d

echo "Waiting for container to start..."
sleep 3

# Check container status
if docker ps | grep -q falco-test-ubuntu; then
    echo "âœ?Container started successfully"
    echo ""
    echo "=========================================="
    echo "Next steps:"
    echo "1. Enter container: docker exec -it falco-test-ubuntu bash"
    echo "2. Run installation script in container: /tmp/install_falco.sh"
    echo "3. Or use: docker-compose exec falco-test bash"
    echo "=========================================="
else
    echo "âœ?Container startup failed, please check logs: docker-compose logs"
    exit 1
fi
