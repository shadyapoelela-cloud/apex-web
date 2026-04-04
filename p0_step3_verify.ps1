# APEX P0 - Step 3: Verify Cleanup
# Usage: cd C:\apex_app; .\p0_step3_verify.ps1

$root = "C:\apex_app"
$fe   = "$root\apex_finance"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  APEX P0 - Post-Cleanup Verification"   -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$issues = 0

# Check 1: No .bak files remaining
Write-Host "[Check 1] .bak files in frontend..." -ForegroundColor Yellow
$baks = Get-ChildItem "$fe\lib" -Recurse -Filter "*.bak" -ErrorAction SilentlyContinue
if ($baks.Count -eq 0) {
    Write-Host "  PASS  No .bak files found" -ForegroundColor Green
} else {
    Write-Host "  FAIL  $($baks.Count) .bak file(s) remaining" -ForegroundColor Red
    $baks | ForEach-Object { Write-Host "         $($_.FullName)" -ForegroundColor Red }
    $issues++
}

# Check 2: No duplicate api_config.dart
Write-Host ""
Write-Host "[Check 2] Duplicate api_config.dart..." -ForegroundColor Yellow
if (Test-Path "$fe\lib\api_config.dart") {
    Write-Host "  FAIL  lib\api_config.dart still exists" -ForegroundColor Red
    $issues++
} else {
    Write-Host "  PASS  Only core\api_config.dart exists" -ForegroundColor Green
}

# Check 3: No doc exports in root
Write-Host ""
Write-Host "[Check 3] Documentation files in root..." -ForegroundColor Yellow
$txtInRoot = Get-ChildItem "$root\*.txt" -ErrorAction SilentlyContinue
$remaining = @()
if ($txtInRoot) { $remaining += $txtInRoot }
if (Test-Path "$root\MIGRATION.md") { $remaining += (Get-Item "$root\MIGRATION.md") }
if ($remaining.Count -eq 0) {
    Write-Host "  PASS  No .txt or MIGRATION.md in root" -ForegroundColor Green
} else {
    Write-Host "  WARN  $($remaining.Count) file(s) still in root:" -ForegroundColor Yellow
    $remaining | ForEach-Object { Write-Host "         $($_.Name)" -ForegroundColor Yellow }
}

# Check 4: No build artifacts in root
Write-Host ""
Write-Host "[Check 4] Build artifacts in root..." -ForegroundColor Yellow
$buildFiles = @("flutter.js","flutter_bootstrap.js","flutter_service_worker.js","main.dart.js")
$bf = $buildFiles | Where-Object { Test-Path "$root\$_" }
if ($bf.Count -eq 0) {
    Write-Host "  PASS  No build artifacts in root" -ForegroundColor Green
} else {
    Write-Host "  FAIL  $($bf.Count) build artifact(s) remaining" -ForegroundColor Red
    $issues++
}

# Check 5: Core files intact
Write-Host ""
Write-Host "[Check 5] Core files integrity..." -ForegroundColor Yellow
$coreFiles = @(
    "$fe\lib\main.dart",
    "$fe\lib\core\api_config.dart",
    "$fe\lib\core\router.dart",
    "$fe\lib\core\session.dart",
    "$fe\lib\core\theme.dart",
    "$fe\lib\api_service.dart",
    "$root\app\main.py",
    "$root\app\phase1\models\platform_models.py",
    "$root\app\phase2\models\phase2_models.py",
    "$root\app\sprint1\routes\sprint1_routes.py"
)
$coreOk = 0
foreach ($f in $coreFiles) {
    if (Test-Path $f) {
        $coreOk++
    } else {
        Write-Host "  FAIL  MISSING: $f" -ForegroundColor Red
        $issues++
    }
}
if ($coreOk -eq $coreFiles.Count) {
    Write-Host "  PASS  $coreOk / $($coreFiles.Count) core files present" -ForegroundColor Green
} else {
    Write-Host "  FAIL  $coreOk / $($coreFiles.Count) core files present" -ForegroundColor Red
}

# Check 6: File count after cleanup
Write-Host ""
Write-Host "[Check 6] Project file count..." -ForegroundColor Yellow
$dartFiles = (Get-ChildItem "$fe\lib" -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue).Count
$pyFiles   = (Get-ChildItem "$root\app" -Recurse -Filter "*.py" -ErrorAction SilentlyContinue).Count
Write-Host "  Before cleanup: ~457 files [from V3 report]"
Write-Host "  Dart files now: $dartFiles"
Write-Host "  Python files:   $pyFiles"

# Check 7: Git status
Write-Host ""
Write-Host "[Check 7] Git status..." -ForegroundColor Yellow
Set-Location $root
$gs = git status --short 2>$null
if (-not $gs) {
    Write-Host "  PASS  Working tree clean" -ForegroundColor Green
} else {
    $mod = ($gs | Where-Object { $_ -match '^ M|^M' }).Count
    $unt = ($gs | Where-Object { $_ -match '^\?\?' }).Count
    Write-Host "  INFO  $mod modified, $unt untracked" -ForegroundColor Yellow
}

# Final Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verification Summary"                   -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($issues -eq 0) {
    Write-Host "  ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "  P0 Complete. Next steps:"
    Write-Host "    git push render main"
    Write-Host "    git push origin main"
    Write-Host "    Then proceed to P1 [utf8.decode fix]"
} else {
    Write-Host "  $issues issue(s) found - review above" -ForegroundColor Red
}
Write-Host ""
