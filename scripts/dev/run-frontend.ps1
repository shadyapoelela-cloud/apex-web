# APEX local-dev frontend launcher (G-DEV-1, Sprint 8).
#
# What it does:
#   1. Resolves the project root from this script's location.
#   2. cd's into apex_finance/.
#   3. Prints the exact command + runs `flutter run -d chrome` with the
#      build-time --dart-define=API_BASE override that points the Flutter
#      client at the local uvicorn instance instead of the Render production
#      URL baked into api_config.dart's defaultValue.
#
# Why --dart-define=API_BASE=http://127.0.0.1:8000 is REQUIRED:
#   apex_finance/lib/core/api_config.dart line 12 defaults to the Render
#   production URL (intentional — production and CI builds rely on that
#   default). Without --dart-define, your local Flutter app talks to the
#   live Render backend, NOT the uvicorn you just started. Symptoms: CORS
#   errors, stale data, "Failed to fetch" if Render is cold-starting, or
#   accidentally hitting prod data with dev auth tokens.
#
# Counterpart: scripts/dev/run-backend.ps1 (start FIRST).

param(
    [int]$WebPort = 57305,
    [string]$ApiBase = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"

# --- 1. Resolve project root + 2. cd into apex_finance --------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptRoot "..\..")
$flutterDir = Join-Path $projectRoot "apex_finance"

if (-not (Test-Path $flutterDir)) {
    Write-Host "[run-frontend] ERROR: apex_finance directory not found at $flutterDir" -ForegroundColor Red
    exit 1
}

Set-Location $flutterDir
Write-Host "[run-frontend] cwd: $flutterDir" -ForegroundColor Cyan

# --- 3. Print + run -------------------------------------------------------
$cmd = "flutter run -d chrome --web-port $WebPort --dart-define=API_BASE=$ApiBase"
Write-Host "[run-frontend] cmd: $cmd" -ForegroundColor Cyan
Write-Host "[run-frontend] open http://127.0.0.1:$WebPort/ once Flutter says 'lib/main.dart on Chrome'." -ForegroundColor DarkGray
Write-Host ""

& flutter run -d chrome --web-port $WebPort "--dart-define=API_BASE=$ApiBase"
