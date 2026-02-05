#!/usr/bin/env bash
# Cleanup Docker containers and resources

set -e

echo "=========================================="
echo "Cleanup Falco Test Environment"
echo "=========================================="

# Stop and remove containers
echo "Stopping and removing containers..."
docker-compose down 2>/dev/null || true

# Remove container (if exists by name)
if docker ps -a --format '{{.Names}}' | grep -q "^falco-test-ubuntu$"; then
    echo "Removing container falco-test-ubuntu..."
    docker rm -f falco-test-ubuntu 2>/dev/null || true
fi

# Optional: Remove image (uncomment to enable)
# echo "Removing image..."
# docker rmi falco-config_falco-test 2>/dev/null || true

echo ""
echo "=========================================="
echo "âœ?Cleanup completed"
echo "=========================================="
echo ""
echo "To rebuild environment, run: ./scripts/setup_docker.sh"
echo ""
