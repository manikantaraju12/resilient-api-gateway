# Environment Configuration Reference

All configuration is managed through environment variables following the 12-factor application principles.

## Quick Start

```bash
# Development
cp .env.example .env
docker-compose up -d

# Production
cp .env.prod .env
docker-compose -f docker-compose.prod.yml up -d
```

## Variables Reference

### Application Settings

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `PORT` | `5000` | `1-65535` | HTTP server port |
| `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR` | Logging verbosity |
| `ENVIRONMENT` | `development` | `development`, `staging`, `production` | Deployment environment |

**Example:**
```bash
PORT=8080
LOG_LEVEL=DEBUG
ENVIRONMENT=production
```

### Redis Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `redis` | Redis server hostname/IP |
| `REDIS_PORT` | `6379` | Redis server port |
| `REDIS_PASSWORD` | `` | Redis authentication password (empty = no auth) |
| `REDIS_DB` | `0` | Redis database number |
| `REDIS_TIMEOUT` | `5` | Connection timeout in seconds |

**Example - Local Redis:**
```bash
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

**Example - Production Redis (with auth):**
```bash
REDIS_HOST=redis.production.internal
REDIS_PORT=6379
REDIS_PASSWORD=secure_password_here
REDIS_DB=0
```

**Example - AWS ElastiCache:**
```bash
REDIS_HOST=my-cluster.abc123.ng.0001.use1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=auth_token_here
```

### Upstream Service Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `UPSTREAM_URL` | `http://upstream-service:5001` | Base URL of upstream service |
| `UPSTREAM_TIMEOUT` | `30` | Request timeout in seconds |
| `UPSTREAM_VERIFY_SSL` | `true` | Verify SSL certificates |

**Example - Local upstream:**
```bash
UPSTREAM_URL=http://localhost:5001
UPSTREAM_TIMEOUT=30
```

**Example - Remote upstream:**
```bash
UPSTREAM_URL=https://api.partner.com
UPSTREAM_TIMEOUT=60
UPSTREAM_VERIFY_SSL=true
```

**Example - Multiple upstream (load balanced):**
```bash
# Configure via Nginx upstream instead
UPSTREAM_URL=http://nginx-lb:8080
```

### Rate Limiter Configuration

Token Bucket algorithm implementation with Redis backend.

| Variable | Default | Recommended | Description |
|----------|---------|-------------|-------------|
| `RATE_LIMIT_CAPACITY` | `100` | `1000-10000` | Max tokens per client per hour |
| `RATE_LIMIT_REFILL_RATE` | `10` | `100-500` | Tokens refilled per minute |
| `RATE_LIMIT_TTL` | `3600` | `3600` | Time-to-live for rate limit state (seconds) |

**Token Calculation:**
```
Requests per hour = CAPACITY
Requests per minute = CAPACITY / 60
Time to refill one token = 60 / REFILL_RATE seconds
```

**Example - Strict (IoT/Public API):**
```bash
RATE_LIMIT_CAPACITY=100
RATE_LIMIT_REFILL_RATE=10  # ~1 request/sec
```

**Example - Moderate (Web Applications):**
```bash
RATE_LIMIT_CAPACITY=1000
RATE_LIMIT_REFILL_RATE=100  # ~10 requests/sec
```

**Example - Generous (Internal/Trusted):**
```bash
RATE_LIMIT_CAPACITY=10000
RATE_LIMIT_REFILL_RATE=1000  # ~100 requests/sec
```

### Circuit Breaker Configuration

Monitors upstream service health and prevents cascading failures.

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `CIRCUIT_BREAKER_FAILURE_THRESHOLD` | `5` | `1-100` | Failures before opening circuit |
| `CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS` | `60` | `10-3600` | Seconds in OPEN state before HALF_OPEN |
| `CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD` | `2` | `1-10` | Successes needed to close circuit |
| `CIRCUIT_BREAKER_WINDOW_SECONDS` | `60` | `10-300` | Time window for failure counting |

**States:**
- `CLOSED`: Normal operation, requests forwarded
- `OPEN`: Upstream unhealthy, requests rejected with 503
- `HALF_OPEN`: Testing if upstream recovered, limited requests allowed

**State Transitions:**
```
CLOSED → [failures ≥ threshold] → OPEN
OPEN → [timeout expired] → HALF_OPEN
HALF_OPEN → [successes ≥ threshold] → CLOSED
HALF_OPEN → [failure] → OPEN (reset timeout)
```

**Example - Aggressive (Fail Fast):**
```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=3
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=30
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=1
```

**Example - Moderate (Production Default):**
```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=60
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=2
```

**Example - Tolerant (Internal/Batch):**
```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=20
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=300
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=5
```

## Profile-Based Configurations

### Development Profile

```bash
# .env
PORT=5000
LOG_LEVEL=DEBUG
ENVIRONMENT=development

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

UPSTREAM_URL=http://localhost:5001
UPSTREAM_TIMEOUT=30

RATE_LIMIT_CAPACITY=100
RATE_LIMIT_REFILL_RATE=10

CIRCUIT_BREAKER_FAILURE_THRESHOLD=2
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=30
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=1
```

### Staging Profile

```bash
# .env
PORT=5000
LOG_LEVEL=INFO
ENVIRONMENT=staging

REDIS_HOST=redis.staging.internal
REDIS_PORT=6379
REDIS_PASSWORD=staging_password

UPSTREAM_URL=https://staging-api.internal
UPSTREAM_TIMEOUT=30

RATE_LIMIT_CAPACITY=500
RATE_LIMIT_REFILL_RATE=50

CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=60
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=2
```

### Production Profile

```bash
# .env.prod
PORT=5000
LOG_LEVEL=WARNING
ENVIRONMENT=production

REDIS_HOST=redis.prod.internal
REDIS_PORT=6379
REDIS_PASSWORD=production_secure_password

UPSTREAM_URL=https://api.production.com
UPSTREAM_TIMEOUT=45

RATE_LIMIT_CAPACITY=2000
RATE_LIMIT_REFILL_RATE=200

CIRCUIT_BREAKER_FAILURE_THRESHOLD=10
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=120
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=3
```

## Per-Client Rate Limiting (Advanced)

To apply different rate limits per client IP:

```bash
# Option 1: Use X-Forwarded-For header
curl -H "X-Forwarded-For: 192.168.1.100" http://localhost:5000/proxy/path

# Option 2: In Nginx, set header from authenticated user
proxy_set_header X-Forwarded-For $http_x_user_id;
```

Then modify rate limiter to:
```python
client_key = request.headers.get('X-User-ID', request.client.host)
```

## Validation Rules

The application validates environment variables on startup:

```
PORT: Must be integer between 1-65535
LOG_LEVEL: Must be in [DEBUG, INFO, WARNING, ERROR]
REDIS_HOST: Must be valid hostname/IP
REDIS_PORT: Must be integer between 1-65535
RATE_LIMIT_CAPACITY: Must be positive integer
CIRCUIT_BREAKER_FAILURE_THRESHOLD: Must be positive integer
```

**Invalid configuration example:**
```bash
# This will cause startup error
PORT=invalid
RATE_LIMIT_CAPACITY=-100
```

## Changing Configuration at Runtime

For single-instance deployments:

```bash
# Edit .env
vi .env

# Restart container
docker-compose restart proxy-service
```

For Kubernetes deployments:

```bash
# Update ConfigMap
kubectl edit configmap api-gateway-config -n api-gateway

# Restart pods to pick up new config
kubectl rollout restart deployment proxy-service -n api-gateway
```

For Kubernetes, changes take effect without restart:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-gateway-config
data:
  RATE_LIMIT_CAPACITY: "5000"
  # Changes here automatically picked up (if app polls config)
```

## Troubleshooting Configuration

### Application won't start

```bash
# Check for syntax errors
docker-compose logs proxy-service | grep -i "error\|invalid"

# Verify .env file
cat .env

# Check required variables are set
docker-compose config
```

### Rate limiting not working

```bash
# Verify rate limit capacity
echo $RATE_LIMIT_CAPACITY

# Check Redis connection
docker-compose exec redis redis-cli PING

# Reset rate limit state
docker-compose exec redis redis-cli DEL "api-gateway:rate-limit:*"
```

### Circuit breaker stuck

```bash
# Check circuit state
docker-compose exec redis redis-cli HGETALL api-gateway:circuit-breaker

# Reset circuit
docker-compose exec redis redis-cli DEL api-gateway:circuit-breaker

# Verify with new failures threshold
# May need to adjust CIRCUIT_BREAKER_FAILURE_THRESHOLD
```

## Performance Tuning

### For High Throughput

```bash
RATE_LIMIT_CAPACITY=5000
RATE_LIMIT_REFILL_RATE=500
CIRCUIT_BREAKER_FAILURE_THRESHOLD=10
```

### For Low Latency

```bash
UPSTREAM_TIMEOUT=10  # Lower timeout
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=30  # Fail fast
```

### For Stability

```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=20
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=180
LOG_LEVEL=DEBUG  # Better diagnostics
```

## Security Best Practices

1. **Never commit secrets to Git**
   ```bash
   echo ".env" >> .gitignore
   ```

2. **Use strong Redis passwords in production**
   ```bash
   REDIS_PASSWORD=$(openssl rand -base64 32)
   ```

3. **Rotate credentials regularly**
   ```bash
   # Update in .env.prod every 90 days
   REDIS_PASSWORD=new_secure_password_here
   docker-compose restart redis
   ```

4. **Restrict log levels in production**
   ```bash
   LOG_LEVEL=WARNING  # Don't log sensitive data
   ```

5. **Use environment variable files instead of shell export**
   ```bash
   # Good
   docker-compose --env-file .env up -d

   # Avoid
   export REDIS_PASSWORD=secret; docker-compose up -d
   ```
