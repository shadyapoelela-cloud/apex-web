# scripts/g-a3-1/install_prereqs.ps1
# G-A3.1.1 (Sprint 12+) -- Windows operator prereq installer.
#
# Why this script exists:
#   During G-A3.1 Phase 2b (2026-05-03), the operator's machine had no
#   PostgreSQL CLI installed. Two retries of `winget install
#   PostgreSQL.PostgreSQL.17` and `.16` died at 134 MB / ~350 MB with
#   HTTP 403 Forbidden against the EnterpriseDB CDN -- the operator was
#   in Saudi Arabia and EDB's CDN appears to block that region. The
#   operator worked around it by composing alembic-stamp-head SQL via
#   psycopg2 inline (see APEX_BLUEPRINT/09 section 2 G-A3.1 closure paragraph
#   for the exact statements run). The maintenance window stretched
#   from 30 min to 90 min as a result.
#
#   This script:
#     1. Verifies Python is available (the only hard requirement).
#     2. Installs psycopg2-binary (user-scope, no admin, no CDN
#        dependency -- comes from PyPI).
#     3. REPORTS whether psql is available -- informational only. We
#        intentionally do NOT try to install it. If a future operator
#        is also blocked by EDB's regional 403, psycopg2 covers every
#        DB op the runbook needs.
#
# Usage:
#     pwsh -File scripts/g-a3-1/install_prereqs.ps1
#
# Exit codes:
#     0 = Python + psycopg2 available (psql may or may not be present).
#     1 = Python missing OR psycopg2 install failed.

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Item, [bool]$Ok, [string]$Detail = "")
    $mark = if ($Ok) { "OK" } else { "MISSING" }
    $color = if ($Ok) { "Green" } else { "Red" }
    Write-Host "[$mark] $Item" -ForegroundColor $color -NoNewline
    if ($Detail) { Write-Host "  $Detail" } else { Write-Host "" }
}

Write-Host "G-A3.1.1 operator prereq installer (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. Python -----------------------------------------------------
$pythonOk = $false
$pythonVersion = ""
try {
    $pythonVersion = (& py --version 2>&1) -join ' '
    if ($LASTEXITCODE -eq 0) {
        $pythonOk = $true
    }
} catch {
    $pythonOk = $false
}
Write-Status "Python (`py --version`)" $pythonOk $pythonVersion

if (-not $pythonOk) {
    Write-Host ""
    Write-Host "Python is required. Install from:" -ForegroundColor Yellow
    Write-Host "  https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "Then re-run this script." -ForegroundColor Yellow
    exit 1
}

# -- 2. psycopg2-binary --------------------------------------------
$psycopg2Ok = $false
$psycopg2Version = ""

# Detect existing install via `pip show`.
$showOutput = & py -m pip show psycopg2-binary 2>&1
if ($LASTEXITCODE -eq 0) {
    $psycopg2Ok = $true
    $versionLine = $showOutput | Where-Object { $_ -match "^Version:" } | Select-Object -First 1
    if ($versionLine) {
        $psycopg2Version = $versionLine -replace "^Version:\s*", ""
    }
} else {
    # Not installed -- try to install user-scope.
    Write-Host "[INFO] psycopg2-binary not installed; installing (user scope)..." -ForegroundColor Cyan
    & py -m pip install --user psycopg2-binary 2>&1 | ForEach-Object {
        Write-Host "  $_"
    }
    if ($LASTEXITCODE -eq 0) {
        # Re-check.
        $showOutput = & py -m pip show psycopg2-binary 2>&1
        if ($LASTEXITCODE -eq 0) {
            $psycopg2Ok = $true
            $versionLine = $showOutput | Where-Object { $_ -match "^Version:" } | Select-Object -First 1
            if ($versionLine) {
                $psycopg2Version = $versionLine -replace "^Version:\s*", ""
            }
        }
    }
}

# Verify import.
if ($psycopg2Ok) {
    $importCheck = & py -c "import psycopg2; print(psycopg2.__version__)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $psycopg2Ok = $false
        $psycopg2Version = "import failed: $importCheck"
    }
}
Write-Status "psycopg2-binary" $psycopg2Ok $psycopg2Version

if (-not $psycopg2Ok) {
    Write-Host ""
    Write-Host "psycopg2-binary install or import failed." -ForegroundColor Red
    Write-Host "Try manually:" -ForegroundColor Yellow
    Write-Host "  py -m pip install --user psycopg2-binary" -ForegroundColor Yellow
    exit 1
}

# -- 3. psql (INFORMATIONAL ONLY -- see header for why) -------------
$psqlOk = $false
$psqlVersion = ""
try {
    $psqlVersion = (& psql --version 2>&1) -join ' '
    if ($LASTEXITCODE -eq 0) {
        $psqlOk = $true
    }
} catch {
    $psqlOk = $false
}
if ($psqlOk) {
    Write-Status "psql (optional)" $true $psqlVersion
} else {
    Write-Host "[ABSENT] psql (optional)  -- psycopg2 covers all DB ops; psql install is intentionally NOT attempted (see header)." -ForegroundColor Yellow
}

# -- Summary -------------------------------------------------------
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
$psqlMark = if ($psqlOk) { "OK" } else { "absent (optional)" }
Write-Host "  Python: OK  |  psycopg2: OK  |  psql: $psqlMark"
Write-Host ""
Write-Host "Operator can proceed to scripts/g-a3-1/preflight.py and stamp_head.py." -ForegroundColor Green
exit 0
