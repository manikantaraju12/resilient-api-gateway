#!/usr/bin/env bash

# Quick Start Guide for Resilient API Gateway
# This script provides interactive deployment options

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Resilient API Gateway - Quick Start                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    echo "   https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    echo "   https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✓ Docker and Docker Compose are available"
echo ""

# Menu
echo "Choose deployment option:"
echo ""
echo "  1) Development (local testing)"
echo "  2) Production (single host)"
echo "  3) Production + Monitoring (Prometheus/Grafana)"
echo "  4) Kubernetes (cloud-ready)"
echo "  5) Run tests only"
echo "  6) View documentation"
echo "  7) Exit"
echo ""
read -p "Enter option (1-7): " option

case $option in
    1)
        echo ""
        echo "🚀 Starting development environment..."
        echo ""
        
        # Copy env file
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "📝 Created .env from .env.example"
        fi
        
        # Start services
        docker-compose up -d --build
        
        # Wait for health
        echo ""
        echo "⏳ Waiting for services to be healthy..."
        sleep 5
        
        # Health check
        if curl -s http://localhost:5000/health > /dev/null 2>&1; then
            echo "✓ Services are healthy!"
            echo ""
            echo "📋 Available URLs:"
            echo "   Health: http://localhost:5000/health"
            echo "   Proxy:  http://localhost:5000/proxy/ok"
            echo ""
            echo "📊 View logs:"
            echo "   docker-compose logs -f proxy-service"
            echo ""
            echo "🧪 Run tests:"
            echo "   docker-compose exec proxy-service pytest tests -v"
        else
            echo "⚠️  Services starting up, check logs:"
            docker-compose logs proxy-service
        fi
        ;;
        
    2)
        echo ""
        echo "🚀 Preparing production deployment..."
        echo ""
        
        # Verify production files
        if [ ! -f docker-compose.prod.yml ]; then
            echo "❌ docker-compose.prod.yml not found"
            exit 1
        fi
        
        if [ ! -f .env.prod ]; then
            echo "❌ .env.prod not found"
            exit 1
        fi
        
        echo "📝 Configuration files found"
        echo ""
        echo "⚙️  Review production settings:"
        grep -E "^(RATE_LIMIT|CIRCUIT_BREAKER|REDIS|UPSTREAM)" .env.prod
        echo ""
        read -p "Continue with deployment? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
        
        # Deploy
        bash deploy.sh prod
        
        echo ""
        echo "✓ Production deployment complete!"
        echo ""
        echo "📋 Health check:"
        echo "   curl http://localhost:5000/health"
        ;;
        
    3)
        echo ""
        echo "🚀 Starting production + monitoring stack..."
        echo ""
        
        # Start services
        docker-compose -f docker-compose.prod.yml \
                      -f docker-compose.monitoring.yml up -d
        
        echo "⏳ Waiting for services to be healthy..."
        sleep 10
        
        echo ""
        echo "✓ Services started!"
        echo ""
        echo "📊 Monitoring URLs:"
        echo "   Prometheus: http://localhost:9090"
        echo "   Grafana:    http://localhost:3000 (admin/admin)"
        echo "   Redis Exp:  http://localhost:9121"
        echo ""
        echo "📋 API URLs:"
        echo "   Health: http://localhost:5000/health"
        echo "   Proxy:  http://localhost:5000/proxy/ok"
        ;;
        
    4)
        echo ""
        echo "☸️  Kubernetes deployment"
        echo ""
        echo "Prerequisites:"
        echo "  ✓ kubectl configured"
        echo "  ✓ Active cluster connection"
        echo "  ✓ Images pushed to registry"
        echo ""
        echo "Steps:"
        echo "  1. Edit k8s-deployment.yaml and update image references"
        echo "  2. Run: kubectl apply -f k8s-deployment.yaml"
        echo "  3. Check: kubectl get pods -n api-gateway"
        echo ""
        echo "See DEPLOYMENT.md for detailed K8s setup"
        ;;
        
    5)
        echo ""
        echo "🧪 Running test suite..."
        echo ""
        
        # Ensure containers are running
        if ! docker-compose ps proxy-service 2>/dev/null | grep -q "Up"; then
            echo "Starting test environment..."
            docker-compose up -d --build
            sleep 5
        fi
        
        # Run tests
        docker-compose exec proxy-service pytest tests -v --tb=short
        ;;
        
    6)
        echo ""
        echo "📚 Documentation Files:"
        echo ""
        echo "  README.md           - Getting started and API docs"
        echo "  PROJECT_SUMMARY.md  - Complete project overview"
        echo "  DEPLOYMENT.md       - Deployment guide (all options)"
        echo "  CONFIG.md           - Configuration reference"
        echo "  OPERATIONS.md       - Operations runbook"
        echo ""
        echo "View with: cat <filename> | less"
        echo ""
        ;;
        
    7)
        echo "Goodbye!"
        exit 0
        ;;
        
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "📖 Need help? Check the documentation:"
echo "   - README.md for getting started"
echo "   - DEPLOYMENT.md for deployment options"
echo "   - CONFIG.md for configuration reference"
echo "   - OPERATIONS.md for operational tasks"
echo ""
