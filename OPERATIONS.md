# Operations Runbook

## Quick Reference

| Task | Command |
|------|---------|
| Deploy to production | `bash deploy.sh prod` |
| View service status | `docker-compose ps` |
| View logs | `docker-compose logs -f proxy-service` |
| Health check | `curl http://localhost:5000/health` |
| Stop all services | `docker-compose down` |
| Restart services | `docker-compose restart` |
| Update services | `docker-compose pull && docker-compose up -d` |

## Startup Procedures

### Initial Deployment

```bash
# 1. Prepare server
mkdir -p /opt/resilient-api-gateway
cd /opt/resilient-api-gateway

# 2. Clone application
git clone <repo-url> .

# 3. Configure environment
cp .env.prod .env
# Edit .env with production values
vi .env

# 4. Deploy
bash deploy.sh prod

# 5. Verify
curl http://localhost:5000/health
docker-compose logs proxy-service

# 6. Configure monitoring (optional)
docker-compose -f docker-compose.monitoring.yml up -d

# 7. Configure Nginx reverse proxy (optional)
sudo cp nginx.conf /etc/nginx/sites-available/api-gateway
sudo systemctl reload nginx
```

### Daily Checks

**Morning Briefing (Start of Shift)**

```bash
# Check service health
echo "=== Service Status ==="
docker-compose ps

# Check resource usage
echo "=== Resource Usage ==="
docker stats --no-stream

# Check recent errors
echo "=== Recent Errors (last 100 lines) ==="
docker-compose logs --tail=100 proxy-service | grep -i error

# Check circuit breaker status
echo "=== Circuit Breaker State ==="
docker-compose exec redis redis-cli GET "api-gateway:circuit-breaker"

# Check rate limiting stats
echo "=== Rate Limit Stats ==="
docker-compose exec redis redis-cli KEYS "api-gateway:rate-limit:*" | wc -l
```

### Pre-Production Checklist

Before going live:

```bash
# [ ] Load test with Apache Bench
ab -n 1000 -c 10 http://localhost:5000/health

# [ ] Verify rate limiting
for i in {1..100}; do curl -s http://localhost:5000/proxy/ok; done | grep -c 429

# [ ] Test circuit breaker
for i in {1..20}; do curl -s http://localhost:5000/proxy/fail; done
sleep 35
curl http://localhost:5000/proxy/ok

# [ ] Check logs for errors
docker-compose logs proxy-service | tail -50

# [ ] Verify Redis persistence
docker-compose exec redis redis-cli BGSAVE

# [ ] Test backup
docker exec $(docker-compose ps -q redis) redis-cli BGSAVE

# [ ] Review configuration
cat .env
```

## Incident Response

### Service Down

**Alert:** `ServiceDown` (service unreachable)

**Steps:**
1. Check service status
   ```bash
   docker-compose ps
   docker-compose logs proxy-service
   ```

2. Check resource availability
   ```bash
   docker stats --no-stream
   free -h
   df -h
   ```

3. Restart service
   ```bash
   docker-compose restart proxy-service
   sleep 10
   curl http://localhost:5000/health
   ```

4. If still down, full restart
   ```bash
   docker-compose restart
   sleep 15
   docker-compose logs proxy-service
   ```

5. If persists, investigate logs
   ```bash
   docker logs $(docker-compose ps -q proxy-service) | tail -100
   ```

### High Error Rate

**Alert:** `UpstreamHighErrorRate` (>5% 5xx responses)

**Investigation:**
```bash
# Check upstream service
docker-compose exec proxy-service curl -v http://upstream-service:5001/health

# Check logs
docker-compose logs upstream-service | tail -50

# Check resource usage
docker stats upstream-service

# Restart upstream if necessary
docker-compose restart upstream-service
```

### Circuit Breaker Stuck Open

**Alert:** `CircuitBreakerFrequentlyOpen`

**Resolution:**
```bash
# 1. Verify circuit state
docker-compose exec redis redis-cli HGETALL api-gateway:circuit-breaker

# 2. Check upstream health
docker-compose exec proxy-service curl -v http://upstream-service:5001/health

# 3. Fix upstream issue or reset circuit
docker-compose exec redis redis-cli DEL api-gateway:circuit-breaker

# 4. Verify circuit is closed
sleep 2
docker-compose exec redis redis-cli HGETALL api-gateway:circuit-breaker

# 5. Test proxy
curl http://localhost:5000/proxy/ok
```

### High Rate Limit Rejections

**Alert:** `HighRateLimitRejections` (>0.1 req/s being rate-limited)

**Investigation:**
```bash
# Check who's being rate-limited
docker-compose exec redis redis-cli KEYS "api-gateway:rate-limit:*" | head -20

# Check specific IP
docker-compose exec redis redis-cli HGETALL "api-gateway:rate-limit:192.168.1.100"

# Option 1: Increase rate limit
vi .env
# Change: RATE_LIMIT_CAPACITY=5000 (from 1000)
docker-compose restart proxy-service

# Option 2: Whitelist IP in Nginx
# Add to nginx.conf: limit_req_status 200; for specific IPs
```

### Redis Memory Critical

**Alert:** `RedisHighMemoryUsage` (>80%)

**Response:**
```bash
# Check memory usage
docker-compose exec redis redis-cli INFO memory

# Option 1: Clear expired keys
docker-compose exec redis redis-cli FLUSHDB

# Option 2: Increase Redis memory limit
docker-compose down
vi docker-compose.prod.yml
# Change memory limit in deploy.resources.limits.memory
docker-compose up -d

# Option 3: Enable eviction policy
docker-compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### High Response Latency

**Alert:** `HighResponseLatency` (p95 > 1s)

**Investigation:**
```bash
# Check upstream latency
time curl http://localhost:5000/proxy/slow  # Should be 2s+

# Check network latency
docker-compose exec proxy-service ping upstream-service

# Check Redis latency
docker-compose exec redis redis-cli --latency

# Monitor in real-time
docker stats proxy-service --no-stream --interval=1
```

**Resolution:**
```bash
# 1. Scale up proxy-service (if using orchestration)
kubectl scale deployment proxy-service -n api-gateway --replicas=5

# 2. Or increase resources
vi docker-compose.prod.yml
# Increase: deploy.resources.limits.cpus and memory

# 3. Restart
docker-compose restart proxy-service
```

## Maintenance Procedures

### Regular Maintenance (Weekly)

```bash
# Update base images
docker-compose pull
docker-compose up -d

# Clean up unused images
docker image prune -f

# Check for security vulnerabilities
docker scout cves resilient-api-gateway:latest

# Verify backups
ls -lah redis-backups/
```

### Monthly Maintenance

```bash
# Full system update
docker-compose down
docker system prune -a

# Rebuild images
docker-compose build --no-cache

# Deploy fresh
docker-compose up -d --build

# Run full test suite
docker-compose exec proxy-service pytest tests -v

# Verify all endpoints
./test-endpoints.sh
```

### Quarterly Maintenance

```bash
# Review and update dependencies
# In requirements.txt: pip install --upgrade pip-tools
# pip-compile --upgrade requirements.in

# Security audit
# Run SAST tools, dependency checkers

# Performance profiling
# Enable profiling in config
# Review and optimize slow queries

# Update documentation
# Review runbook, update procedures
```

## Backup & Recovery

### Backup Schedule

**Daily (2 AM UTC):**
```bash
# Automated Redis backup
0 2 * * * docker-compose -f /opt/api-gateway/docker-compose.prod.yml exec -T redis redis-cli BGSAVE
```

**Weekly (Sunday 3 AM UTC):**
```bash
# Full application backup
0 3 * * 0 tar -czf /backup/api-gateway-$(date +\%Y\%m\%d).tar.gz /opt/resilient-api-gateway
```

**Manual Backup:**
```bash
# Backup Redis
docker-compose exec redis redis-cli BGSAVE
docker cp $(docker-compose ps -q redis):/data/dump.rdb ./redis-backup-$(date +%s).rdb

# Backup application
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz .env docker-compose.prod.yml

# Upload to S3
aws s3 cp redis-backup-*.rdb s3://my-backup-bucket/
aws s3 cp backup-*.tar.gz s3://my-backup-bucket/
```

### Recovery Procedures

**From Redis Snapshot:**
```bash
# 1. Stop services
docker-compose down

# 2. Restore dump.rdb
docker cp redis-backup-1234567890.rdb $(docker-compose ps -q redis):/data/dump.rdb

# 3. Restart
docker-compose up -d

# 4. Verify
docker-compose exec redis redis-cli INFO stats
```

**Full Application Recovery:**
```bash
# 1. Delete corrupted data
rm -rf /opt/resilient-api-gateway

# 2. Extract backup
tar -xzf /backup/api-gateway-20240101.tar.gz -C /opt

# 3. Restart
cd /opt/resilient-api-gateway
docker-compose -f docker-compose.prod.yml up -d
```

## Performance Tuning

### Rate Limiter Tuning

**For IoT/High Frequency Clients:**
```bash
RATE_LIMIT_CAPACITY=10000
RATE_LIMIT_REFILL_RATE=1000
```

**For Web/Mobile Clients:**
```bash
RATE_LIMIT_CAPACITY=1000
RATE_LIMIT_REFILL_RATE=100
```

**For API Partner:**
```bash
RATE_LIMIT_CAPACITY=500
RATE_LIMIT_REFILL_RATE=50
```

### Circuit Breaker Tuning

**Aggressive (Fail Fast):**
```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=3
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=30
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=1
```

**Tolerant (Allow More Failures):**
```bash
CIRCUIT_BREAKER_FAILURE_THRESHOLD=20
CIRCUIT_BREAKER_RESET_TIMEOUT_SECONDS=300
CIRCUIT_BREAKER_HALF_OPEN_SUCCESS_THRESHOLD=5
```

## Scaling Guidelines

### Vertical Scaling (More Resources)

```bash
# Edit docker-compose.prod.yml
deploy:
  resources:
    limits:
      cpus: '2'      # Increase from 1
      memory: 1G     # Increase from 512M
```

### Horizontal Scaling (More Replicas)

**Kubernetes:**
```bash
kubectl scale deployment proxy-service -n api-gateway --replicas=10
```

**Docker Compose (multiple nodes):**
```bash
# Use Docker Swarm or orchestration tool
docker service create --replicas 5 resilient-api-gateway:latest
```

## Monitoring Integration

### Prometheus Queries

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_5xx_total[5m]) / rate(http_requests_total[5m])

# Rate limit hit rate
rate(http_requests_429_total[5m]) / rate(http_requests_total[5m])

# Circuit breaker state (1=CLOSED, 2=OPEN, 3=HALF_OPEN)
circuit_breaker_state

# Redis memory usage
redis_memory_used_bytes / redis_memory_max_bytes
```

## Contact & Escalation

| Role | Contact | On-Call |
|------|---------|---------|
| DevOps Lead | team@example.com | slack: #devops-oncall |
| Platform Engineer | platform@example.com | slack: #platform |
| Database Admin | dba@example.com | slack: #dba-oncall |

**Critical Incident:** Page on-call via PagerDuty or equivalent.

## Additional Resources

- [Troubleshooting Guide](DEPLOYMENT.md#troubleshooting)
- [API Documentation](README.md#api)
- [Architecture Overview](README.md#design)
