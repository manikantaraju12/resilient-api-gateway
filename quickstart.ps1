# PowerShell Quick Start - Resilient API Gateway
# This script provides interactive deployment for Windows systems

param(
    [switch]$SkipChecks = $false
)

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║   Resilient API Gateway - Quick Start (PowerShell)             ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Check prerequisites
if (-not $SkipChecks) {
    Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
    
    $checks = @{
        "Docker" = { docker --version }
        "Docker Compose" = { docker-compose --version }
        "Git" = { git --version }
    }
    
    foreach ($check in $checks.GetEnumerator()) {
        try {
            & $check.Value | Out-Null
            Write-Host "✓ $($check.Key) is installed" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ $($check.Key) not found" -ForegroundColor Red
            Write-Host "  Please install $($check.Key) first" -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host "`nChoose deployment option:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Development (local testing)"
Write-Host "  2) Production (single host)"
Write-Host "  3) Production + Monitoring"
Write-Host "  4) View Documentation"
Write-Host "  5) Run Tests"
Write-Host "  6) Exit"
Write-Host ""

$option = Read-Host "Enter option (1-6)"

switch ($option) {
    "1" {
        Write-Host "`n🚀 Starting development environment..." -ForegroundColor Green
        
        # Copy env file if needed
        if (-not (Test-Path ".env")) {
            if (Test-Path ".env.example") {
                Copy-Item ".env.example" ".env"
                Write-Host "📝 Created .env from .env.example" -ForegroundColor Cyan
            }
        }
        
        # Start services
        Write-Host "Starting Docker services..." -ForegroundColor Cyan
        & docker-compose up -d --build
        
        # Wait for services
        Write-Host "`n⏳ Waiting for services to be healthy..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Health check
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ Services are healthy!" -ForegroundColor Green
                Write-Host "`n📋 Available URLs:" -ForegroundColor Cyan
                Write-Host "   Health: http://localhost:5000/health"
                Write-Host "   Proxy:  http://localhost:5000/proxy/ok"
                Write-Host "`n📊 View logs:" -ForegroundColor Cyan
                Write-Host "   docker-compose logs -f proxy-service"
                Write-Host "`n🧪 Run tests:" -ForegroundColor Cyan
                Write-Host "   docker-compose exec proxy-service pytest tests -v"
            }
        }
        catch {
            Write-Host "⚠️  Services starting, checking logs..." -ForegroundColor Yellow
            & docker-compose logs proxy-service | Select-Object -Last 20
        }
    }
    
    "2" {
        Write-Host "`n🚀 Preparing production deployment..." -ForegroundColor Green
        
        # Verify files
        $requiredFiles = @("docker-compose.prod.yml", ".env.prod")
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path $file)) {
                Write-Host "❌ $file not found" -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "📝 Configuration files found" -ForegroundColor Green
        Write-Host "`n⚙️  Production settings:" -ForegroundColor Cyan
        
        $envContent = Get-Content ".env.prod"
        $envContent | Where-Object { $_ -match "^(RATE_LIMIT|CIRCUIT_BREAKER|REDIS|UPSTREAM)" } | ForEach-Object {
            Write-Host "   $_"
        }
        
        $confirm = Read-Host "`nContinue with deployment? (y/n)"
        if ($confirm -ne "y") {
            Write-Host "Deployment cancelled" -ForegroundColor Yellow
            exit 0
        }
        
        # Deploy using docker-compose
        Write-Host "`n📦 Building images..." -ForegroundColor Cyan
        & docker-compose -f docker-compose.prod.yml build --no-cache
        
        Write-Host "`n📦 Pulling images..." -ForegroundColor Cyan
        & docker-compose -f docker-compose.prod.yml pull
        
        Write-Host "`n🛑 Stopping old containers..." -ForegroundColor Cyan
        & docker-compose -f docker-compose.prod.yml down | Out-Null
        
        Write-Host "`n🚀 Starting services..." -ForegroundColor Cyan
        & docker-compose -f docker-compose.prod.yml up -d
        
        Write-Host "`n⏳ Waiting for services to be healthy..." -ForegroundColor Yellow
        $maxAttempts = 30
        $attempt = 0
        $healthy = $false
        
        while ($attempt -lt $maxAttempts -and -not $healthy) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    $healthy = $true
                }
            }
            catch {
                # Still waiting
            }
            
            if (-not $healthy) {
                Write-Host "  Waiting for services to be ready... ($($attempt + 1)/$maxAttempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                $attempt++
            }
        }
        
        if ($healthy) {
            Write-Host "`n✓ Deployment successful!" -ForegroundColor Green
            Write-Host "`n📋 Service Status:" -ForegroundColor Cyan
            & docker-compose -f docker-compose.prod.yml ps
            Write-Host "`nProxy service available at: http://localhost:5000" -ForegroundColor Green
        }
        else {
            Write-Host "`n❌ Services failed to become healthy" -ForegroundColor Red
            & docker-compose -f docker-compose.prod.yml logs proxy-service | Select-Object -Last 50
            exit 1
        }
    }
    
    "3" {
        Write-Host "`n🚀 Starting production + monitoring stack..." -ForegroundColor Green
        
        Write-Host "Starting services..." -ForegroundColor Cyan
        & docker-compose -f docker-compose.prod.yml -f docker-compose.monitoring.yml up -d
        
        Write-Host "`n⏳ Waiting for services (10 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        Write-Host "`n✓ Services started!" -ForegroundColor Green
        Write-Host "`n📊 Monitoring URLs:" -ForegroundColor Cyan
        Write-Host "   Prometheus: http://localhost:9090"
        Write-Host "   Grafana:    http://localhost:3000 (admin/admin)"
        Write-Host "   Redis Exp:  http://localhost:9121"
        Write-Host "`n📋 API URLs:" -ForegroundColor Cyan
        Write-Host "   Health: http://localhost:5000/health"
        Write-Host "   Proxy:  http://localhost:5000/proxy/ok"
    }
    
    "4" {
        Write-Host "`n📚 Documentation Files:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  • README.md           - Getting started and API docs"
        Write-Host "  • PROJECT_SUMMARY.md  - Complete project overview"
        Write-Host "  • DEPLOYMENT.md       - Deployment guide (all options)"
        Write-Host "  • CONFIG.md           - Configuration reference"
        Write-Host "  • OPERATIONS.md       - Operations runbook"
        Write-Host "  • INDEX.md            - Navigation guide"
        Write-Host ""
        Write-Host "Open with: notepad <filename> or your preferred editor"
        Write-Host ""
    }
    
    "5" {
        Write-Host "`n🧪 Running test suite..." -ForegroundColor Cyan
        
        # Ensure containers are running
        $status = & docker-compose ps proxy-service 2>&1
        if ($status -notmatch "Up") {
            Write-Host "Starting test environment..." -ForegroundColor Yellow
            & docker-compose up -d --build
            Start-Sleep -Seconds 5
        }
        
        Write-Host "Running pytest..." -ForegroundColor Cyan
        & docker-compose exec proxy-service pytest tests -v --tb=short
    }
    
    "6" {
        Write-Host "`nGoodbye!" -ForegroundColor Cyan
        exit 0
    }
    
    default {
        Write-Host "`n❌ Invalid option" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n📖 Need help? Check the documentation:" -ForegroundColor Cyan
Write-Host "   • README.md for getting started"
Write-Host "   • DEPLOYMENT.md for deployment options"
Write-Host "   • CONFIG.md for configuration"
Write-Host "   • OPERATIONS.md for operational tasks"
Write-Host ""
