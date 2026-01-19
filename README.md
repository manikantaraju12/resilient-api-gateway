# Resilient API Gateway

A robust API Gateway proxy implementing distributed Token Bucket rate limiting and a Redis-backed Circuit Breaker. Includes Docker Compose orchestration with a dummy upstream service.

## Setup

- Copy `.env.example` to `.env` and adjust values if needed.
- Build and start services:

```bash
docker-compose up -d --build
```

- Run tests inside the proxy container:

```bash
docker-compose exec proxy-service pytest tests/
```

## API

- GET `/health`: `{ "status": "healthy" }`
- ANY `/proxy/{path}`: Proxies to `UPSTREAM_URL`.
  - 429: `{ "error": "Too many requests, please try again later." }` with `Retry-After`.
  - 503: `{ "error": "Service temporarily unavailable due to circuit open." }` when circuit is OPEN.

## Configuration (env)

- `PORT`: Proxy port.
- `REDIS_HOST`, `REDIS_PORT`: Redis connection.
- `UPSTREAM_URL`: Base upstream URL.
- `RATE_LIMIT_CAPACITY`, `RATE_LIMIT_REFILL_RATE`: Token bucket params.
- `CIRCUIT_BREAKER_FAILURE_THRESHOLD`, `CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS`, `CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD`: Circuit breaker params.

## Design

- Token Bucket implemented via a Redis Lua script for atomic refill/consume keyed by client IP.
- Circuit Breaker states (`CLOSED`, `OPEN`, `HALF_OPEN`) stored in Redis hash with thresholds and timestamps.
- Proxy forwards method, path, headers, and body; appends `X-Forwarded-For`.
- Structured logging for requests, rate limit blocks, circuit transitions, and upstream errors.

## Upstream Dummy

- Flask app exposing `/health`, `/ok`, `/users`, `/products`, `/slow`, `/fail`, and `/echo`.

## Deployment

### Docker Compose (Single Host)

**Development:**
```bash
docker-compose up -d --build
```

**Production:**
```bash
# Copy and customize production environment
cp .env.prod .env

# Run automated deployment script
bash deploy.sh prod

# Or manual deployment
docker-compose -f docker-compose.prod.yml up -d
```

**Features:**
- Resource limits (CPU/Memory per container)
- Persistent Redis data volume (`redis_data`)
- JSON-file logging with rotation (10MB per file, 3 files max)
- Restart policies (unless stopped)
- Health checks for service readiness
- Service dependencies enforcement

**Configuration for docker-compose.prod.yml:**
- `.env.prod` contains production-tuned parameters:
  - `RATE_LIMIT_CAPACITY=1000` (requests per hour per client)
  - `RATE_LIMIT_REFILL_RATE=100` (refill rate)
  - Higher circuit breaker thresholds for production tolerance

### Kubernetes (Cloud-Ready)

Deploy to Kubernetes cluster using `k8s-deployment.yaml`:

```bash
# Create namespace and deploy
kubectl apply -f k8s-deployment.yaml

# Verify deployment
kubectl get pods -n api-gateway
kubectl get svc -n api-gateway

# Port forward for local testing
kubectl port-forward -n api-gateway svc/proxy-service 5000:5000

# View logs
kubectl logs -n api-gateway deployment/proxy-service
```

**Kubernetes Features:**
- Dedicated namespace (`api-gateway`)
- ConfigMap for environment variables
- PersistentVolumeClaim for Redis data (5Gi)
- Horizontal Pod Autoscaling (3-10 replicas, 70% CPU/80% memory targets)
- Pod Disruption Budget (min 2 available replicas)
- Liveness & readiness probes
- Resource requests/limits
- Security context (non-root user)

**Accessing the Service:**
- Internal: `http://proxy-service.api-gateway.svc.cluster.local:5000`
- External: `kubectl port-forward svc/proxy-service 5000:5000` or LoadBalancer IP

### GitHub Actions CI/CD

Automated pipeline with stages: test → build → deploy-staging → deploy-production.

**Setup:**
1. Create GitHub secrets:
   - `DOCKER_USERNAME`: Docker Hub username
   - `DOCKER_PASSWORD`: Docker Hub password
   - `STAGING_DEPLOY_KEY`: SSH private key for staging server
   - `STAGING_HOST`: Staging server hostname
   - `STAGING_USER`: SSH user for staging
   - `PROD_DEPLOY_KEY`: SSH private key for production server
   - `PROD_HOST`: Production server hostname
   - `PROD_USER`: SSH user for production

2. Push code:
   - Pushes to `develop` branch trigger test → build → deploy-staging
   - Pushes to `main` branch trigger test → build → deploy-production (requires manual approval)

3. Pipeline jobs:
   - **test**: Lint (flake8), run pytest with coverage, upload to Codecov
   - **build**: Docker buildx, build and push to Docker Hub (tags: git SHA + latest)
   - **deploy-staging**: SSH deploy, docker-compose pull/up, run test suite
   - **deploy-production**: SSH deploy, git pull main, smoke tests (health checks)

## Monitoring & Observability

### Health Checks

```bash
# Service health
curl http://localhost:5000/health

# Proxy connectivity (should fail or succeed based on upstream)
curl http://localhost:5000/proxy/health
```

### Logs

**Docker Compose:**
```bash
docker-compose logs -f proxy-service
docker-compose logs -f redis
```

**Kubernetes:**
```bash
kubectl logs -f -n api-gateway deployment/proxy-service
kubectl logs -f -n api-gateway deployment/redis
```

### Metrics

- Rate limiter: Track 429 responses per IP
- Circuit breaker: Monitor OPEN/HALF_OPEN state transitions
- Upstream latency: Measure response times
- Error rate: Track 5xx failures

All events logged in structured JSON format with timestamps.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 429 Too Many Requests | Adjust `RATE_LIMIT_CAPACITY` or `RATE_LIMIT_REFILL_RATE` in `.env` |
| 503 Service Unavailable | Circuit breaker is OPEN; upstream service may be unhealthy |
| Redis connection error | Verify Redis is running and `REDIS_HOST`/`REDIS_PORT` are correct |
| Tests failing in CI | Check docker image building and registry push permissions |
| Kubernetes pod not ready | Check resource availability, review pod logs with `kubectl describe pod <name>` |

## Rollback Procedures

**Docker Compose:**
```bash
# Keep previous container images
docker-compose down
# Previous version: update .env and restart
docker-compose -f docker-compose.prod.yml up -d
```

**Kubernetes:**
```bash
# Rollback to previous deployment revision
kubectl rollout history -n api-gateway deployment/proxy-service
kubectl rollout undo -n api-gateway deployment/proxy-service --to-revision=1
```

**GitHub Actions:**
Deployment jobs can be skipped by not pushing to `main`/`develop` branches, or manually revert in Git and push.
