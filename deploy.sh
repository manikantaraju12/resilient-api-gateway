#!/bin/bash
set -e

echo "====== Resilient API Gateway - Production Deployment ======"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed"
    exit 1
fi

# Configuration
ENVIRONMENT=${1:-prod}
DOCKER_COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"

echo "Deploying to: $ENVIRONMENT"
echo "Using docker-compose file: $DOCKER_COMPOSE_FILE"
echo "Using env file: $ENV_FILE"

# Verify files exist
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Error: $DOCKER_COMPOSE_FILE not found"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

# Build images
echo "Step 1: Building Docker images..."
docker-compose -f $DOCKER_COMPOSE_FILE build --no-cache

# Pull latest images if using pre-built images
echo "Step 2: Pulling latest images..."
docker-compose -f $DOCKER_COMPOSE_FILE pull

# Stop old containers if they exist
echo "Step 3: Stopping old containers..."
docker-compose -f $DOCKER_COMPOSE_FILE down || true

# Start new containers
echo "Step 4: Starting services..."
docker-compose -f $DOCKER_COMPOSE_FILE up -d

# Wait for services to be healthy
echo "Step 5: Waiting for services to be healthy..."
RETRIES=30
for i in $(seq 1 $RETRIES); do
    if docker-compose -f $DOCKER_COMPOSE_FILE exec -T proxy-service curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✓ Services are healthy"
        break
    fi
    if [ $i -eq $RETRIES ]; then
        echo "✗ Services failed to become healthy after $RETRIES attempts"
        docker-compose -f $DOCKER_COMPOSE_FILE logs
        exit 1
    fi
    echo "Waiting for services to be ready... ($i/$RETRIES)"
    sleep 2
done

# Run tests
echo "Step 6: Running tests..."
docker-compose -f $DOCKER_COMPOSE_FILE exec -T proxy-service python -m pytest tests -q

# Display status
echo ""
echo "====== Deployment successful! ======"
echo ""
docker-compose -f $DOCKER_COMPOSE_FILE ps
echo ""
echo "Proxy service available at: http://localhost:5000"
echo "Health check: curl http://localhost:5000/health"
echo ""
