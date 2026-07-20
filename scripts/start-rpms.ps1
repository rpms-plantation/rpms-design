# ============================================================================
# RPMS Full-Stack Startup Script
# Starts: Docker infra → 6 backends (M1→M2→M4→M3→M5→M6) → Angular shell
#
# Usage:
#   .\start-rpms.ps1
#   .\start-rpms.ps1 -RpmsRoot "D:\Projects\RPMS"
#   .\start-rpms.ps1 -SkipDocker -SkipShell
# ============================================================================

param(
    [string]$RpmsRoot  = "C:\Personal\Projects\RPMS",
    [switch]$SkipDocker,
    [switch]$SkipShell,
    [switch]$RebuildAll
)

$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }

function Wait-Port($port, $label, $timeoutSec = 120) {
    Write-Host "    Waiting for $label on port $port..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("localhost", $port)
            $tcp.Close()
            Write-Host " ready" -ForegroundColor Green
            return $true
        } catch { Start-Sleep -Seconds 2; Write-Host "." -NoNewline }
    }
    Write-Host " TIMED OUT" -ForegroundColor Red
    return $false
}

function Wait-Http($url, $label, $timeoutSec = 120) {
    Write-Host "    Waiting for $label at $url ..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($r.StatusCode -lt 400) { Write-Host " ready ($($r.StatusCode))" -ForegroundColor Green; return $true }
        } catch {}
        Start-Sleep -Seconds 3; Write-Host "." -NoNewline
    }
    Write-Host " TIMED OUT" -ForegroundColor Red
    return $false
}

function Start-Backend($name, $dir, $jar, $port, $buildCmd) {
    Write-Step "Starting $name (port $port)"
    $fullDir = Join-Path $RpmsRoot $dir
    $jarPath = Join-Path $fullDir $jar

    if ($RebuildAll -or -not (Test-Path $jarPath)) {
        Write-Host "    Building $name ..."
        Push-Location $fullDir
        try { Invoke-Expression $buildCmd } finally { Pop-Location }
        if (-not (Test-Path $jarPath)) {
            Write-Warn "Build failed — jar not found at $jarPath. Skipping $name."
            return
        }
    } else {
        Write-OK "Jar exists — skipping build (pass -RebuildAll to force rebuild)"
    }

    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "Write-Host '$name' -ForegroundColor Cyan; cd '$fullDir'; java -jar '$jar'"
    ) -WindowStyle Normal

    Wait-Port $port $name | Out-Null
}

# ── 0. Verify paths ───────────────────────────────────────────────────────────

Write-Step "RPMS root: $RpmsRoot"
if (-not (Test-Path $RpmsRoot)) {
    Write-Error "RPMS root not found: $RpmsRoot. Pass -RpmsRoot to override."
    exit 1
}

# ── 1. Docker infra ───────────────────────────────────────────────────────────

if (-not $SkipDocker) {
    Write-Step "Starting Docker infra"
    $dockerDir = Join-Path $RpmsRoot "rpms-platform\infra\docker"
    Push-Location $dockerDir
    docker compose -p rpms-full -f docker-compose.full.yml up -d
    Pop-Location

    Write-Step "Waiting for infrastructure"
    Wait-Port 5432 "PostgreSQL"      | Out-Null
    Wait-Port 9092 "Kafka"           | Out-Null
    Wait-Port 6379 "Redis"           | Out-Null
    # Keycloak health check is flaky — poll the realm URL directly
    Wait-Http "http://localhost:8180/realms/rpms" "Keycloak (rpms realm)" 180 | Out-Null
    Write-OK "Infrastructure ready"
} else {
    Write-Warn "Skipping Docker (–SkipDocker flag set)"
}

# ── 2. Backend services (dependency order: M1 → M2 → M4 → M3 → M5 → M6) ──────

# M1 — plantation-service (Spring Boot, port 18081)
Start-Backend `
    "plantation-service (M1)" `
    "rpms-mod-plantation\backend" `
    "target\plantation-service.jar" `
    18081 `
    "mvn clean package -DskipTests -q"

# M2 — tree-service (Spring Boot, port 8082)
Start-Backend `
    "tree-service (M2)" `
    "rpms-mod-tree\backend" `
    "target\tree-service.jar" `
    8082 `
    "mvn clean package -DskipTests -q"

# M4 — workforce-service (Spring Boot, port 8084)
Start-Backend `
    "workforce-service (M4)" `
    "rpms-mod-workforce\backend" `
    "target\workforce-service.jar" `
    8084 `
    "mvn clean package -DskipTests -q"

# M3 — tapping-service (Quarkus, port 8083)
# NOTE: Always rebuilds — the Quarkus fast-jar layout means only mvn package
# produces the runnable quarkus-app/ directory.
Write-Step "Building & starting tapping-service (M3, port 8083)"
$tappingDir = Join-Path $RpmsRoot "rpms-mod-tapping\backend"
Push-Location $tappingDir
Write-Host "    Building tapping-service (Quarkus) — this takes ~30s ..."
mvn clean package -DskipTests -q
if ($LASTEXITCODE -ne 0) {
    Write-Warn "tapping-service build failed — check the output above."
    Pop-Location
} else {
    Pop-Location
    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "Write-Host 'tapping-service (M3)' -ForegroundColor Cyan; cd '$tappingDir'; java -jar 'target\quarkus-app\quarkus-run.jar'"
    ) -WindowStyle Normal
    Wait-Port 8083 "tapping-service" | Out-Null
}

# M5 — activity-service (Quarkus, port 8085)
Write-Step "Building & starting activity-service (M5, port 8085)"
$activityDir = Join-Path $RpmsRoot "rpms-mod-activity\backend"
Push-Location $activityDir
Write-Host "    Building activity-service (Quarkus) ..."
mvn clean package -DskipTests -q
if ($LASTEXITCODE -ne 0) {
    Write-Warn "activity-service build failed."
    Pop-Location
} else {
    Pop-Location
    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "Write-Host 'activity-service (M5)' -ForegroundColor Cyan; cd '$activityDir'; java -jar 'target\quarkus-app\quarkus-run.jar'"
    ) -WindowStyle Normal
    Wait-Port 8085 "activity-service" | Out-Null
}

# M6 — attendance-service (Quarkus, port 8086)
Write-Step "Building & starting attendance-service (M6, port 8086)"
$attendanceDir = Join-Path $RpmsRoot "rpms-mod-attendance\backend"
Push-Location $attendanceDir
Write-Host "    Building attendance-service (Quarkus) ..."
mvn clean package -DskipTests -q
if ($LASTEXITCODE -ne 0) {
    Write-Warn "attendance-service build failed."
    Pop-Location
} else {
    Pop-Location
    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "Write-Host 'attendance-service (M6)' -ForegroundColor Cyan; cd '$attendanceDir'; java -jar 'target\quarkus-app\quarkus-run.jar'"
    ) -WindowStyle Normal
    Wait-Port 8086 "attendance-service" | Out-Null
}

# ── 3. Angular shell ──────────────────────────────────────────────────────────

if (-not $SkipShell) {
    Write-Step "Starting Angular shell (port 4200)"
    $shellDir = Join-Path $RpmsRoot "rpms-shell-web"

    # Re-link local file: deps in case any dist/ changed
    Push-Location $shellDir
    Write-Host "    npm install (re-links local Angular libs) ..."
    npm install --silent
    Pop-Location

    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "Write-Host 'Angular shell' -ForegroundColor Cyan; cd '$shellDir'; npm start"
    ) -WindowStyle Normal

    Wait-Http "http://localhost:4200" "Angular shell" 120 | Out-Null
} else {
    Write-Warn "Skipping Angular shell (–SkipShell flag set)"
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  RPMS Stack is UP" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Web app     : http://localhost:4200" -ForegroundColor White
Write-Host "  Login       : claude.smoketest / SmokeTest123!" -ForegroundColor White
Write-Host ""
Write-Host "  Services:" -ForegroundColor Gray
Write-Host "    plantation-service (M1) : http://localhost:18081/api/plantation/actuator/health"
Write-Host "    tree-service       (M2) : http://localhost:8082/api/tree/actuator/health"
Write-Host "    tapping-service    (M3) : http://localhost:8083/api/tapping/health/live"
Write-Host "    workforce-service  (M4) : http://localhost:8084/api/workforce/actuator/health"
Write-Host "    activity-service   (M5) : http://localhost:8085/api/activity/health/live"
Write-Host "    attendance-service (M6) : http://localhost:8086/api/attendance/health/live"
Write-Host ""
Write-Host "  Infra:" -ForegroundColor Gray
Write-Host "    Keycloak     : http://localhost:8180  (admin/admin)"
Write-Host "    MinIO        : http://localhost:9001  (minio/minio123)"
Write-Host "    Kafdrop      : http://localhost:9000"
Write-Host ""
Write-Host "  To seed demo data:"
Write-Host "    psql -U rpms -d rpms -f rpms-design\scripts\demo-seed-full.sql"
Write-Host ""
