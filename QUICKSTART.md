# 🚀 GET STARTED - Resilient API Gateway

**Your production-ready API Gateway is complete!** Everything is configured, tested, and ready to deploy.

---

## ⚡ Fastest Start (5 minutes)

### Windows PowerShell

```powershell
# 1. Verify setup (one-time)
.\verify-setup.ps1

# 2. Start interactive menu
.\quickstart.ps1

# 3. Choose option 1 for development
# Services will be running at:
#   - Health: http://localhost:5000/health
#   - Proxy: http://localhost:5000/proxy/ok
```

### Bash/Linux/Mac

```bash
# 1. Verify setup
bash verify-setup.sh

# 2. Start interactive menu
bash quickstart.sh

# 3. Choose option 1 for development
```

---

## 📋 What You Have

✅ **Complete Application**
- FastAPI proxy service
- Token Bucket rate limiter
- Circuit breaker pattern
- Redis state management
- Upstream test service

✅ **Multiple Deployment Options**
- Docker Compose (development)
- Docker Compose (production)
- Kubernetes (cloud-scale)
- Systemd (Linux VMs)
- GitHub Actions (CI/CD)

✅ **Full Documentation**
- README - Getting started
- DEPLOYMENT - All deployment options
- CONFIG - Configuration guide
- OPERATIONS - Runbook
- INDEX - Navigation

✅ **Automation Scripts**
- quickstart.ps1/.sh - Interactive setup
- deploy.ps1/.sh - Automated deployment
- verify-setup.ps1/.sh - System verification

✅ **Monitoring & Observability**
- Prometheus metrics
- Grafana dashboards
- Alert rules
- Structured logging

---

## 🎯 3-Step Deployment

### Step 1: Verify Your System (1 minute)

**Windows:**
```powershell
.\verify-setup.ps1
```

**Linux/Mac:**
```bash
bash verify-setup.sh
```

This checks:
- ✓ Docker installed
- ✓ Docker Compose installed
- ✓ Project files present
- ✓ Ports available

### Step 2: Start Services (2 minutes)

**Option A: Interactive (Recommended)**

```powershell
.\quickstart.ps1
```

Choose your deployment option:
1. Development (local testing)
2. Production (single host)
3. Production + Monitoring

**Option B: Direct Command**

```bash
# Development
docker-compose up -d --build

# Production
docker-compose -f docker-compose.prod.yml up -d

# Production + Monitoring
docker-compose -f docker-compose.prod.yml -f docker-compose.monitoring.yml up -d
```

### Step 3: Verify It Works (1 minute)

```bash
# Check health
curl http://localhost:5000/health

# Test proxy
curl http://localhost:5000/proxy/ok

# View logs
docker-compose logs -f proxy-service
```

---

## 🔍 Verify Everything Works

### Health Checks

```bash
# API Gateway health
curl http://localhost:5000/health
# Expected: {"status":"healthy"}

# Test proxy forwarding
curl http://localhost:5000/proxy/users
# Expected: JSON array of users from upstream

# Test rate limiting
for i in {1..10}; do curl http://localhost:5000/proxy/ok; done
# Expected: First 3 succeed, rest get 429
```

### View Logs

```bash
# Proxy service
docker-compose logs -f proxy-service

# Redis
docker-compose logs -f redis

# All services
docker-compose logs -f
```

### Check Metrics (if monitoring enabled)

```
Prometheus: http://localhost:9090
Grafana:    http://localhost:3000  (admin/admin)
```

---

## ⚙️ Configuration

### For Development
```bash
# Default .env is fine for local testing
# No changes needed - just run and go!
```

### For Production
```bash
# Edit .env.prod for your environment
# Key settings:
RATE_LIMIT_CAPACITY=1000        # Requests per hour per IP
CIRCUIT_BREAKER_FAILURE_THRESHOLD=10  # Failures before opening
UPSTREAM_URL=https://your-api.com

# Then deploy
docker-compose -f docker-compose.prod.yml up -d
```

### Tuning Parameters

**High Performance:**
```
RATE_LIMIT_CAPACITY=5000
RATE_LIMIT_REFILL_RATE=500
CIRCUIT_BREAKER_FAILURE_THRESHOLD=10
```

**Strict Rate Limiting:**
```
RATE_LIMIT_CAPACITY=100
RATE_LIMIT_REFILL_RATE=10
CIRCUIT_BREAKER_FAILURE_THRESHOLD=3
```

See [CONFIG.md](CONFIG.md) for all options.

---

## 📚 Documentation

| File | Purpose | Read When |
|------|---------|-----------|
| [README.md](README.md) | Overview & API docs | Getting started |
| [DEPLOYMENT.md](DEPLOYMENT.md) | How to deploy | Ready to deploy |
| [CONFIG.md](CONFIG.md) | Configuration reference | Need to tune |
| [OPERATIONS.md](OPERATIONS.md) | Daily operations | Running in production |
| [INDEX.md](INDEX.md) | Documentation index | Need to find something |

---

## 🛠️ Common Tasks

### Start Development
```powershell
.\quickstart.ps1
# Choose: 1
```

### Deploy to Production
```powershell
.\deploy.ps1 -Environment prod
```

### Add Monitoring
```bash
docker-compose -f docker-compose.prod.yml \
               -f docker-compose.monitoring.yml up -d
```

### Run Tests
```powershell
.\quickstart.ps1
# Choose: 5
```

### View Logs
```bash
docker-compose logs -f proxy-service
```

### Stop Services
```bash
docker-compose down
```

### Full Restart
```bash
docker-compose restart
```

---

## 🧪 Test the Gateway

### Rate Limiter Test
```bash
# Should succeed (first 3)
for i in {1..5}; do 
  curl http://localhost:5000/proxy/ok
  echo "Request $i"
done
# Requests 4-5 should get HTTP 429
```

### Circuit Breaker Test
```bash
# Trigger failures
for i in {1..15}; do 
  curl http://localhost:5000/proxy/fail
done

# Should get 503 (circuit open)
curl http://localhost:5000/proxy/ok
# Expected: 503 Service Unavailable

# Wait 60 seconds, then should work again
sleep 60
curl http://localhost:5000/proxy/ok
# Expected: 200 OK
```

### Load Test
```bash
# Send 100 concurrent requests
for i in {1..100}; do 
  curl http://localhost:5000/proxy/ok & 
done
wait
```

---

## 🚨 Troubleshooting

### Services won't start
```bash
# Check if ports are in use
# Windows:
Get-NetTCPConnection -LocalPort 5000

# Linux:
lsof -i :5000

# Solution: Stop other services or use different ports
```

### Container already exists
```bash
# Clean up old containers
docker-compose down
docker-compose up -d
```

### Can't connect to Docker
```bash
# Make sure Docker Desktop is running
# Windows: Start Docker Desktop application
# Mac: Start Docker Desktop application
# Linux: Start Docker daemon
```

### Out of disk space
```bash
# Clean up unused Docker resources
docker system prune -a
```

### Redis connection error
```bash
# Check Redis is running
docker-compose ps redis

# Check logs
docker-compose logs redis

# Restart Redis
docker-compose restart redis
```

See [OPERATIONS.md](OPERATIONS.md) for more troubleshooting.

---

## 🚀 Next Steps

### Immediate (Now)
1. Run: `.\quickstart.ps1`
2. Choose development (option 1)
3. Verify: `curl http://localhost:5000/health`

### Short Term (This week)
1. Read [DEPLOYMENT.md](DEPLOYMENT.md)
2. Configure for your upstream
3. Deploy to staging

### Medium Term (This month)
1. Setup monitoring
2. Configure alerting
3. Run load tests

### Long Term (Ongoing)
1. Monitor in production
2. Optimize based on metrics
3. Scale as needed

---

## 📊 What's Running

After startup, you'll have:

**Development Stack** (3 containers)
- Redis (in-memory cache)
- Upstream Service (Flask dummy API)
- Proxy Service (FastAPI gateway)

**Production Stack** (same + logging)
- Resource limits per container
- Persistent Redis data
- Structured JSON logging

**With Monitoring** (production + 3 more)
- Prometheus (metrics collection)
- Grafana (dashboards)
- Redis Exporter (metrics)

---

## 🔗 Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| API Gateway | http://localhost:5000 | Main entry point |
| Health Check | http://localhost:5000/health | Service health |
| Proxy | http://localhost:5000/proxy/* | Forward to upstream |
| Prometheus | http://localhost:9090 | Metrics (if monitoring) |
| Grafana | http://localhost:3000 | Dashboards (if monitoring) |
| Redis Exp | http://localhost:9121 | Redis metrics (if monitoring) |

---

## ✅ Deployment Checklist

Before production:

- [ ] Run `.\verify-setup.ps1`
- [ ] Read [DEPLOYMENT.md](DEPLOYMENT.md)
- [ ] Configure .env.prod
- [ ] Run tests: `.\quickstart.ps1` → Option 5
- [ ] Test rate limiting manually
- [ ] Test circuit breaker manually
- [ ] Setup monitoring
- [ ] Configure backup
- [ ] Document your setup
- [ ] Team training

---

## 💡 Pro Tips

✅ **Keep logs handy**
```bash
docker-compose logs -f --tail=100
```

✅ **Check stats**
```bash
docker stats
```

✅ **Backup Redis**
```bash
docker-compose exec redis redis-cli BGSAVE
docker cp $(docker-compose ps -q redis):/data/dump.rdb backup.rdb
```

✅ **Update images**
```bash
docker-compose pull
docker-compose up -d
```

✅ **Clean up**
```bash
docker system prune -a
docker volume prune
```

---

## 📞 Need Help?

1. **Setup issues:** Run `.\verify-setup.ps1` 
2. **Deployment questions:** See [DEPLOYMENT.md](DEPLOYMENT.md)
3. **Configuration help:** See [CONFIG.md](CONFIG.md)
4. **Operations:** See [OPERATIONS.md](OPERATIONS.md)
5. **Find anything:** See [INDEX.md](INDEX.md)

---

## 🎉 You're All Set!

Everything you need is ready:
- ✓ Application code
- ✓ Docker configuration
- ✓ Kubernetes manifests
- ✓ Deployment scripts
- ✓ Comprehensive documentation
- ✓ Monitoring and alerting
- ✓ CI/CD pipeline

**Start here:** `.\quickstart.ps1`

**Then read:** [DEPLOYMENT.md](DEPLOYMENT.md)

**Reference:** [CONFIG.md](CONFIG.md)

---

**Happy deploying! 🚀**

*Last Updated: 2024-01-01*  
*Status: Production Ready ✓*
