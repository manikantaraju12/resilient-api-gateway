# PowerShell Verification & Setup Script
# Validates and sets up the complete deployment package

param(
    [switch]$Full = $false
)

$ErrorActionPreference = "Continue"

Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║   Resilient API Gateway - Verification & Setup                    ║
╚═══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

$issues = @()
$warnings = @()
$success = @()

# Check system requirements
Write-Host "`n📋 Checking System Requirements..." -ForegroundColor Yellow

# Docker
try {
    $dockerVersion = & docker --version 2>&1
    if ($?) {
        $success += "✓ Docker installed: $dockerVersion"
    }
}
catch {
    $issues += "✗ Docker not installed or not in PATH"
}

# Docker Compose
try {
    $composeVersion = & docker-compose --version 2>&1
    if ($?) {
        $success += "✓ Docker Compose installed: $composeVersion"
    }
}
catch {
    $issues += "✗ Docker Compose not installed or not in PATH"
}

# Git
try {
    $gitVersion = & git --version 2>&1
    if ($?) {
        $success += "✓ Git installed: $gitVersion"
    }
}
catch {
    $warnings += "⚠️  Git not installed (optional, for version control)"
}

# Python (optional for local development)
try {
    $pythonVersion = & python --version 2>&1
    if ($?) {
        $success += "✓ Python installed: $pythonVersion"
    }
}
catch {
    $warnings += "⚠️  Python not installed (optional, for local development)"
}

# Display requirements
foreach ($msg in $success) {
    Write-Host $msg -ForegroundColor Green
}
foreach ($msg in $warnings) {
    Write-Host $msg -ForegroundColor Yellow
}
foreach ($msg in $issues) {
    Write-Host $msg -ForegroundColor Red
}

if ($issues.Count -gt 0) {
    Write-Host "`n❌ Critical requirements not met. Please install missing components." -ForegroundColor Red
    exit 1
}

# Check project files
Write-Host "`n📁 Checking Project Files..." -ForegroundColor Yellow

$requiredFiles = @(
    "Dockerfile",
    "requirements.txt",
    "docker-compose.yml",
    "docker-compose.prod.yml",
    ".env.example",
    ".env.prod",
    "README.md",
    "DEPLOYMENT.md"
)

$requiredDirs = @(
    "src",
    "tests",
    "upstream_service"
)

$fileStatus = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $file (missing)" -ForegroundColor Red
        $fileStatus = $false
    }
}

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir -PathType Container) {
        Write-Host "✓ $dir/" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $dir/ (missing)" -ForegroundColor Red
        $fileStatus = $false
    }
}

if (-not $fileStatus) {
    Write-Host "`n⚠️  Some files are missing. Run from project root directory." -ForegroundColor Yellow
}

# Check Docker daemon
Write-Host "`n🐳 Checking Docker Daemon..." -ForegroundColor Yellow
try {
    & docker ps > $null 2>&1
    if ($?) {
        Write-Host "✓ Docker daemon is running" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Docker daemon is not running" -ForegroundColor Red
    Write-Host "  Please start Docker Desktop" -ForegroundColor Yellow
    if ($PSVersionTable.OS -match "Windows") {
        Write-Host "  On Windows: Start Docker Desktop application" -ForegroundColor Gray
    }
}

# Check ports
Write-Host "`n🔌 Checking Ports..." -ForegroundColor Yellow
$ports = @{
    "5000" = "API Gateway"
    "5001" = "Upstream Service"
    "6379" = "Redis"
    "9090" = "Prometheus"
    "3000" = "Grafana"
}

foreach ($port in $ports.GetEnumerator()) {
    $tcpConnection = Get-NetTCPConnection -LocalPort $port.Key -ErrorAction SilentlyContinue
    if ($tcpConnection) {
        Write-Host "⚠️  Port $($port.Key) is already in use ($($port.Value))" -ForegroundColor Yellow
    }
    else {
        Write-Host "✓ Port $($port.Key) available ($($port.Value))" -ForegroundColor Green
    }
}

# Setup .env if needed
Write-Host "`n⚙️  Configuration Setup..." -ForegroundColor Yellow

if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Write-Host "Creating .env from .env.example..." -ForegroundColor Cyan
        Copy-Item ".env.example" ".env"
        Write-Host "✓ .env created" -ForegroundColor Green
        Write-Host "  Edit .env to customize settings" -ForegroundColor Gray
    }
}
else {
    Write-Host "✓ .env already exists" -ForegroundColor Green
}

# Display summary
Write-Host "`n" -ForegroundColor White
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   ✓ VERIFICATION COMPLETE                                         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📖 Quick Start Options:" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Interactive Setup:"
Write-Host "     .\quickstart.ps1"
Write-Host ""
Write-Host "  2. Development (Quick):"
Write-Host "     docker-compose up -d --build"
Write-Host ""
Write-Host "  3. Production Deployment:"
Write-Host "     .\deploy.ps1 -Environment prod"
Write-Host ""
Write-Host "  4. Production + Monitoring:"
Write-Host "     docker-compose -f docker-compose.prod.yml -f docker-compose.monitoring.yml up -d"
Write-Host ""

Write-Host "`n📚 Documentation:" -ForegroundColor Green
Write-Host "  • Start with: README.md"
Write-Host "  • Then read: DEPLOYMENT.md"
Write-Host "  • Ref guide: CONFIG.md"
Write-Host "  • Operations: OPERATIONS.md"
Write-Host "  • Index:      INDEX.md"
Write-Host ""

if ($Full) {
    Write-Host "`n🔍 Detailed Configuration Check..." -ForegroundColor Yellow
    Write-Host "`n.env contents (sanitized):" -ForegroundColor Cyan
    if (Test-Path ".env") {
        Get-Content ".env" | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object {
            if ($_ -match "PASSWORD|SECRET|KEY") {
                Write-Host "  [REDACTED]"
            }
            else {
                Write-Host "  $_"
            }
        }
    }
}

Write-Host "`n✨ System is ready for deployment!" -ForegroundColor Green
Write-Host ""
