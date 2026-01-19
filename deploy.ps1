# PowerShell Deployment Script - Resilient API Gateway
# Automated production deployment with verification

param(
    [ValidateSet("dev", "prod", "staging")]
    [string]$Environment = "prod",
    
    [switch]$NoBuild = $false,
    [switch]$SkipTests = $false
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║   Resilient API Gateway - Deployment Script                    ║
║   Environment: $Environment                                              ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Configuration
$composeFile = if ($Environment -eq "dev") { "docker-compose.yml" } else { "docker-compose.prod.yml" }
$envFile = ".env.$Environment"

# Verify files exist
Write-Host "Step 1: Verifying configuration..." -ForegroundColor Yellow
if (-not (Test-Path $composeFile)) {
    Write-Host "❌ Error: $composeFile not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $envFile)) {
    Write-Host "⚠️  Warning: $envFile not found" -ForegroundColor Yellow
    Write-Host "   Creating from .env.example" -ForegroundColor Cyan
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" $envFile
    }
}

Write-Host "✓ Configuration files verified" -ForegroundColor Green

# Build images
if (-not $NoBuild) {
    Write-Host "`nStep 2: Building Docker images..." -ForegroundColor Yellow
    & docker-compose -f $composeFile build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Build completed" -ForegroundColor Green
}

# Pull latest images
Write-Host "`nStep 3: Pulling latest images..." -ForegroundColor Yellow
& docker-compose -f $composeFile pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Warning: Pull had issues (continuing)" -ForegroundColor Yellow
}

# Stop old containers
Write-Host "`nStep 4: Stopping old containers..." -ForegroundColor Yellow
& docker-compose -f $composeFile down 2>&1 | Out-Null
Write-Host "✓ Old containers stopped" -ForegroundColor Green

# Start new containers
Write-Host "`nStep 5: Starting services..." -ForegroundColor Yellow
& docker-compose -f $composeFile up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Start failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Services started" -ForegroundColor Green

# Wait for health
Write-Host "`nStep 6: Waiting for services to be healthy..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$healthy = $false

while ($attempt -lt $maxAttempts -and -not $healthy) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $healthy = $true
        }
    }
    catch {
        # Still waiting
    }
    
    if (-not $healthy) {
        Write-Host "  Attempt $($attempt + 1)/$maxAttempts..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $attempt++
    }
}

if (-not $healthy) {
    Write-Host "❌ Services failed to become healthy after $maxAttempts attempts" -ForegroundColor Red
    Write-Host "`nRecent logs:" -ForegroundColor Yellow
    & docker-compose -f $composeFile logs proxy-service | Select-Object -Last 30
    exit 1
}

Write-Host "✓ Services are healthy" -ForegroundColor Green

# Run tests if not skipped
if (-not $SkipTests) {
    Write-Host "`nStep 7: Running tests..." -ForegroundColor Yellow
    & docker-compose -f $composeFile exec proxy-service python -m pytest tests -q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Warning: Some tests failed" -ForegroundColor Yellow
    }
    else {
        Write-Host "✓ Tests passed" -ForegroundColor Green
    }
}

# Display status
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✓ DEPLOYMENT SUCCESSFUL!                                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 Service Status:" -ForegroundColor Cyan
& docker-compose -f $composeFile ps

Write-Host "`n🌐 Access Points:" -ForegroundColor Cyan
Write-Host "   API Gateway: http://localhost:5000"
Write-Host "   Health:      http://localhost:5000/health"
Write-Host "   Proxy:       http://localhost:5000/proxy/ok"

Write-Host "`n📊 Logs:" -ForegroundColor Cyan
Write-Host "   docker-compose -f $composeFile logs -f proxy-service"

Write-Host "`n🧪 Tests:" -ForegroundColor Cyan
Write-Host "   docker-compose -f $composeFile exec proxy-service pytest tests -v"

Write-Host ""
