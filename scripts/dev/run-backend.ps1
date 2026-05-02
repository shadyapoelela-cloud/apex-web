# APEX local-dev backend launcher (G-DEV-1, Sprint 8).
#
# What it does:
#   1. Resolves the project root from this script's location (no hard-coded
#      paths — works from any clone path).
#   2. Checks if TCP/8000 is already listening; if so, prints the offending
#      PID and asks before killing it. (Common cause: a previous run-backend
#      that was Ctrl+C'd in a way that left the child uvicorn alive.)
#   3. Prints the exact command it is about to run.
#   4. Starts uvicorn bound to 127.0.0.1:8000 with --reload.
#
# Why 127.0.0.1 (not localhost or 0.0.0.0):
#   - localhost can resolve to ::1 (IPv6) on Windows 11, and uvicorn's default
#     bind on 127.0.0.1 won't accept those connections — the browser then sees
#     "Failed to fetch" and the user blames the backend.
#   - 0.0.0.0 binds to every interface, exposing dev to the LAN. Don't.
#   - 127.0.0.1 is what app/main.py prints in its lifespan startup message,
#     so the runbook stays consistent with the logs.
#
# Companion: scripts/dev/run-backend.sh (Mac/Linux).
# Counterpart: scripts/dev/run-frontend.ps1 (start AFTER this).

param(
    [int]$Port = 8000,
    [string]$BindHost = "127.0.0.1",
    [switch]$NoReload
)

$ErrorActionPreference = "Stop"

# --- 1. Resolve project root from script location -------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptRoot "..\..")
Write-Host "[run-backend] project root: $projectRoot" -ForegroundColor Cyan

# --- 2. Check whether port is already in use ------------------------------
$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    $existingPid = $existing[0].OwningProcess
    $proc = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
    $procName = if ($proc) { $proc.ProcessName } else { "unknown" }
    Write-Host "[run-backend] WARNING: port $Port is already listening (PID $existingPid, $procName)." -ForegroundColor Yellow
    $resp = Read-Host "Kill it and continue? [y/N]"
    if ($resp -match '^(y|yes)$') {
        Stop-Process -Id $existingPid -Force
        Start-Sleep -Seconds 1
        Write-Host "[run-backend] killed PID $existingPid." -ForegroundColor Green
    } else {
        Write-Host "[run-backend] aborted. Free port $Port and re-run." -ForegroundColor Red
        exit 1
    }
}

# --- 3. Print the exact command + 4. Run ----------------------------------
Set-Location $projectRoot

# Auto-set CORS_ORIGINS for local dev (G-DEV-1.1).
# Backend defaults to '*' which is incompatible with credentials:'include'
# used by the Flutter web client. Setting explicit origins enables CORS.
if (-not $env:CORS_ORIGINS) {
    $env:CORS_ORIGINS = "http://localhost:57305,http://127.0.0.1:57305"
    Write-Host "CORS_ORIGINS auto-set for local dev: $env:CORS_ORIGINS" -ForegroundColor Cyan
}

$reloadFlag = if ($NoReload) { "" } else { " --reload" }
$cmd = "py -m uvicorn app.main:app --host $BindHost --port $Port$reloadFlag"
Write-Host "[run-backend] cwd: $projectRoot" -ForegroundColor Cyan
Write-Host "[run-backend] cmd: $cmd" -ForegroundColor Cyan
Write-Host "[run-backend] (Ctrl+C to stop)" -ForegroundColor DarkGray
Write-Host ""

# Use the call operator with explicit args so PowerShell doesn't re-tokenize.
$args = @("-m", "uvicorn", "app.main:app", "--host", $BindHost, "--port", "$Port")
if (-not $NoReload) { $args += "--reload" }
& py @args
