# Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Development](#local-development)
3. [Docker Compose (Single Host)](#docker-compose-single-host)
4. [Kubernetes (Multi-Host)](#kubernetes-multi-host)
5. [Linux Server Deployment](#linux-server-deployment)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Security Checklist](#security-checklist)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### For All Environments
- Docker 20.10+ and Docker Compose 1.29+ (or Docker Compose v2)
- Git
- Python 3.11+ (for local testing)
- 2GB+ RAM available
- Internet access for pulling images

### For Kubernetes
- kubectl CLI
- Active Kubernetes cluster (v1.20+)
- Persistent volume provisioner (local-path or similar)
- Ingress controller (optional, for external access)

### For Linux Server
- Ubuntu 20.04+ or similar Linux distribution
- systemd
- SSH access with sudo privileges

## Local Development

### Quick Start
```bash
# Clone repository
git clone <repository-url>
cd resilient-api-gateway

# Copy environment file
cp .env.example .env

# Start services
docker-compose up -d --build

# Run tests
docker-compose exec proxy-service pytest tests -q

# Verify
curl http://localhost:5000/health
curl http://localhost:5000/proxy/ok
```

### Testing Rate Limiter
```bash
# Should succeed initially
for i in {1..10}; do curl -s http://localhost:5000/proxy/ok | head -c 50; echo; done

# Check rate limiting (capacity=3 by default)
# Requests after 3 should return 429
```

### Testing Circuit Breaker
```bash
# Trigger failures
for i in {1..15}; do curl -s http://localhost:5000/proxy/fail; done

# Circuit should be OPEN now - should return 503
curl http://localhost:5000/proxy/ok

# Wait for timeout (default 30s), then enters HALF_OPEN
sleep 35
curl http://localhost:5000/proxy/ok  # Should succeed and close circuit
```

## Docker Compose (Single Host)

### Production Deployment on Single Server

**Step 1: Prepare Server**
```bash
ssh user@production-server
cd /opt
sudo mkdir resilient-api-gateway
sudo chown user:user resilient-api-gateway
cd resilient-api-gateway
```

**Step 2: Clone and Configure**
```bash
git clone <repository-url> .
cp .env.prod .env
# Edit .env with production settings
nano .env
```

**Step 3: Deploy**
```bash
# Make deploy script executable
chmod +x deploy.sh

# Run deployment
bash deploy.sh prod

# Or manual deployment
docker-compose -f docker-compose.prod.yml up -d

# Verify
docker-compose ps
docker-compose logs proxy-service
```

**Step 4: Configure Nginx (Optional)
```bash
# Copy Nginx config
sudo cp nginx.conf /etc/nginx/sites-available/api-gateway
sudo ln -s /etc/nginx/sites-available/api-gateway /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

**Step 5: Set up Systemd (Optional)**
```bash
sudo cp resilient-api-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable resilient-api-gateway
sudo systemctl start resilient-api-gateway
```

### Maintenance Commands

```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f proxy-service

# Update services
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Health check
curl http://localhost:5000/health

# Stop services
docker-compose -f docker-compose.prod.yml down

# Backup Redis data
docker cp $(docker-compose ps -q redis):/data/dump.rdb ./redis-backup-$(date +%s).rdb
```

## Kubernetes (Multi-Host)

### Prerequisites
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configure cluster access
kubectl config use-context <context-name>
kubectl get nodes  # Verify connectivity
```

### Deployment

**Step 1: Build and Push Images**
```bash
# Build images locally
docker build -t your-registry/api-gateway:v1.0.0 .
docker build -t your-registry/upstream-service:v1.0.0 upstream_service/

# Push to registry
docker push your-registry/api-gateway:v1.0.0
docker push your-registry/upstream-service:v1.0.0
```

**Step 2: Update Image References**
Edit `k8s-deployment.yaml` and update image references:
```yaml
image: your-registry/api-gateway:v1.0.0
image: your-registry/upstream-service:v1.0.0
```

**Step 3: Deploy**
```bash
# Apply manifests
kubectl apply -f k8s-deployment.yaml

# Verify
kubectl get all -n api-gateway
kubectl get pvc -n api-gateway
```

**Step 4: Verify Deployment**
```bash
# Check pod status
kubectl get pods -n api-gateway -w

# View logs
kubectl logs -n api-gateway deployment/proxy-service

# Port forward for testing
kubectl port-forward -n api-gateway svc/proxy-service 5000:5000

# Test
curl http://localhost:5000/health
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment proxy-service -n api-gateway --replicas=5

# HPA is configured to auto-scale 3-10 replicas based on CPU/memory
kubectl get hpa -n api-gateway
kubectl describe hpa proxy-service -n api-gateway

# Watch scaling events
kubectl get pods -n api-gateway -w
```

### Updates and Rollbacks

```bash
# Perform rolling update
kubectl set image deployment/proxy-service proxy-service=your-registry/api-gateway:v1.0.1 -n api-gateway

# Monitor rollout
kubectl rollout status deployment/proxy-service -n api-gateway

# View rollout history
kubectl rollout history deployment/proxy-service -n api-gateway

# Rollback to previous version
kubectl rollout undo deployment/proxy-service -n api-gateway
```

## Linux Server Deployment

### Using Systemd

**Step 1: Setup Deployment User**
```bash
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy
```

**Step 2: Prepare Application**
```bash
sudo mkdir -p /opt/resilient-api-gateway
sudo chown deploy:deploy /opt/resilient-api-gateway

# As deploy user
su - deploy
cd /opt/resilient-api-gateway
git clone <repository-url> .
cp .env.prod .env
# Configure .env
```

**Step 3: Install Service**
```bash
sudo cp resilient-api-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable resilient-api-gateway
sudo systemctl start resilient-api-gateway
```

**Step 4: Verify**
```bash
sudo systemctl status resilient-api-gateway
sudo journalctl -u resilient-api-gateway -f
```

### Service Management

```bash
# Start/stop/restart
sudo systemctl start resilient-api-gateway
sudo systemctl stop resilient-api-gateway
sudo systemctl restart resilient-api-gateway

# View logs
sudo journalctl -u resilient-api-gateway -f
sudo journalctl -u resilient-api-gateway --since="2 hours ago"

# Reload after changes
sudo systemctl daemon-reload
sudo systemctl restart resilient-api-gateway
```

## Monitoring & Alerting

### Health Checks

```bash
# Basic health
curl http://localhost:5000/health

# Continuous monitoring
watch -n 5 'curl -s http://localhost:5000/health | jq .'

# With alerting (e.g., using Prometheus)
# See: prometheus.yml (example config)
```

### Logs Aggregation

**Centralized Logging Setup (ELK Stack)**
```yaml
# Add to docker-compose.prod.yml
filebeat:
  image: docker.elastic.co/beats/filebeat:latest
  volumes:
    - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Prometheus Metrics

```bash
# Add to docker-compose.prod.yml
prometheus:
  image: prom/prometheus:latest
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
  ports:
    - "9090:9090"
```

## Security Checklist

### Before Production Deployment

- [ ] Firewall rules configured (80, 443, 5000 as needed)
- [ ] TLS/SSL certificates obtained (Let's Encrypt or CA)
- [ ] Redis password set (`requirepass` in Redis config)
- [ ] API rate limits appropriate for expected traffic
- [ ] Secrets rotated (passwords, tokens, SSH keys)
- [ ] Docker images scanned for vulnerabilities
- [ ] Network policies applied (if using Kubernetes)
- [ ] Backup strategy implemented
- [ ] Monitoring and alerting configured
- [ ] Security headers configured (Nginx/reverse proxy)
- [ ] DDoS protection enabled (if applicable)
- [ ] API keys and authentication implemented

### Linux Server Hardening

```bash
# SSH key-based authentication
# Disable root login
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Firewall rules
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp  # If needed

# Keep system updated
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades

# Audit logs
sudo apt install -y auditd
sudo systemctl enable auditd
```

## Troubleshooting

### Common Issues

**Issue: Port already in use**
```bash
# Find process using port
lsof -i :5000

# Kill process or use different port
kill -9 <PID>
# Or set PORT=5001 in .env
```

**Issue: Redis connection error**
```bash
# Check Redis is running
docker-compose ps redis

# Verify network connectivity
docker-compose exec proxy-service ping redis

# Check Redis logs
docker-compose logs redis
```

**Issue: Circuit breaker stuck OPEN**
```bash
# Reset circuit breaker state
docker-compose exec redis redis-cli
> DEL api-gateway:circuit-breaker

# Or restart services
docker-compose restart
```

**Issue: High memory usage**
```bash
# Check container memory
docker stats

# Review redis memory
docker-compose exec redis redis-cli INFO memory

# Reduce memory limits or implement data eviction policy
```

**Issue: Kubernetes pod not starting**
```bash
# Check pod status
kubectl describe pod <pod-name> -n api-gateway

# View logs
kubectl logs <pod-name> -n api-gateway

# Check events
kubectl get events -n api-gateway --sort-by='.lastTimestamp'
```

### Performance Tuning

**Increase Rate Limit Capacity**
```bash
# Edit .env
RATE_LIMIT_CAPACITY=5000
RATE_LIMIT_REFILL_RATE=500

# Restart
docker-compose -f docker-compose.prod.yml restart proxy-service
```

**Optimize Circuit Breaker**
```bash
# More aggressive circuit breaking
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=60

# More tolerant
CIRCUIT_BREAKER_FAILURE_THRESHOLD=20
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=300
```

**Redis Optimization**
```bash
# Increase max memory
docker-compose -f docker-compose.prod.yml down
# Edit docker-compose.prod.yml, add command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
docker-compose -f docker-compose.prod.yml up -d
```

## Backup & Recovery

### Backup Strategy

```bash
# Daily Redis backup
0 2 * * * docker-compose -f docker-compose.prod.yml exec -T redis redis-cli BGSAVE

# Weekly full backup
0 3 * * 0 tar -czf /backup/api-gateway-$(date +\%Y\%m\%d).tar.gz /opt/resilient-api-gateway

# Store in S3
0 4 * * * aws s3 cp /backup/api-gateway-$(date +\%Y\%m\%d).tar.gz s3://my-bucket/backups/
```

### Recovery

```bash
# From backup
tar -xzf /backup/api-gateway-<date>.tar.gz -C /opt/
docker-compose -f docker-compose.prod.yml up -d

# Restore Redis data
docker cp /backup/dump.rdb $(docker-compose ps -q redis):/data/
docker-compose restart redis
```

## Support & Debugging

For issues, enable debug logging:

```bash
# Set log level
LOG_LEVEL=DEBUG

# Restart services
docker-compose restart
```

Then check logs:
```bash
docker-compose logs -f proxy-service
```
