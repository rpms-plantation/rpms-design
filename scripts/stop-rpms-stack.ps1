<#
.SYNOPSIS
    Stops the full local RPMS stack: Angular shell, all 6 module backends, and (optionally) Docker infra.

.DESCRIPTION
    Finds each service by the port it listens on (see docs/running-rpms-locally.md) and kills the
    owning process. This is more reliable on Windows than matching by process name/jps, since JVM
    tooling (IDE language servers, etc.) can share names with the actual services.

.PARAMETER IncludeInfra
    Also stops the Docker infra containers (Postgres, Kafka, Redis, MinIO, Keycloak, etc.) via
    "docker compose stop". Data is preserved (named volumes are untouched) - this never runs
    "docker compose down -v". Omit this switch to leave infra running (e.g. if the database
    container is shared with other work).

.PARAMETER ComposeProjectName
    The Docker Compose project name the infra stack was originally started with. Must match, or
    Compose may not recognize the running containers as its own. Defaults to 'rpms-full' per
    docs/running-rpms-locally.md. Only used with -IncludeInfra.

.EXAMPLE
    ./stop-rpms-stack.ps1
    Stops the shell and all 6 backends. Leaves Docker infra running.

.EXAMPLE
    ./stop-rpms-stack.ps1 -IncludeInfra
    Stops the shell, all 6 backends, and the Docker infra stack (containers stopped, volumes kept).
#>

param(
    [switch]$IncludeInfra,
    [string]$ComposeProjectName = "rpms-full"
)

$ErrorActionPreference = "Continue"

# Port -> friendly name, matches docs/running-rpms-locally.md "Quick reference - ports"
$services = [ordered]@{
    4200  = "Angular shell"
    18081 = "M1 plantation-service"
    8082  = "M2 tree-service"
    8083  = "M3 tapping-service"
    8084  = "M4 workforce-service"
    8085  = "M5 activity-service"
    8086  = "M6 attendance-service"
}

function Stop-PortOwner {
    param([int]$Port, [string]$Name)

    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "  [$Port] $Name - not running, skipping" -ForegroundColor DarkGray
        return
    }

    $ownerPids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $ownerPids) {
        try {
            $proc = Get-Process -Id $procId -ErrorAction Stop
            Write-Host "  [$Port] $Name - stopping PID $procId ($($proc.ProcessName))" -ForegroundColor Yellow
            Stop-Process -Id $procId -Force -Confirm:$false -ErrorAction Stop
            Write-Host "  [$Port] $Name - stopped" -ForegroundColor Green
        } catch {
            Write-Host "  [$Port] $Name - failed to stop PID $procId : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "=== Stopping RPMS shell + module backends ===" -ForegroundColor Cyan
foreach ($port in $services.Keys) {
    Stop-PortOwner -Port $port -Name $services[$port]
}

if ($IncludeInfra) {
    Write-Host ""
    Write-Host "=== Stopping Docker infra (project: $ComposeProjectName) ===" -ForegroundColor Cyan
    $composeDir = Join-Path $PSScriptRoot "..\..\rpms-platform\infra\docker"

    if (-not (Test-Path $composeDir)) {
        Write-Host "  Could not find $composeDir - is rpms-platform cloned as a sibling repo?" -ForegroundColor Red
        Write-Host "  Skipping infra shutdown. Stop it manually with:" -ForegroundColor Red
        Write-Host "    cd [path-to-rpms-platform]/infra/docker" -ForegroundColor Red
        Write-Host "    docker compose -p $ComposeProjectName -f docker-compose.full.yml stop" -ForegroundColor Red
    } else {
        Push-Location $composeDir
        try {
            # 'stop' (not 'down -v') - preserves named volumes, does not wipe Postgres/Keycloak data
            docker compose -p $ComposeProjectName -f docker-compose.full.yml stop
        } finally {
            Pop-Location
        }
    }
} else {
    Write-Host ""
    Write-Host "Docker infra left running (Postgres, Kafka, Redis, MinIO, Keycloak, etc.)." -ForegroundColor DarkGray
    Write-Host "Re-run with -IncludeInfra to stop it too." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
$stillUp = @()
foreach ($port in $services.Keys) {
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
        $stillUp += $port
    }
}
if ($stillUp.Count -eq 0) {
    Write-Host "All shell/backend ports are down." -ForegroundColor Green
} else {
    Write-Host "Still listening on: $($stillUp -join ', ')" -ForegroundColor Red
}

if ($IncludeInfra) {
    docker ps --filter "label=com.docker.compose.project=$ComposeProjectName" --format "table {{.Names}}\t{{.Status}}"
}
