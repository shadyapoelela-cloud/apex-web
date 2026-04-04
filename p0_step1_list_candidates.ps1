# APEX P0 - Step 1: List Cleanup Candidates (DRY RUN)
# Usage: cd C:\apex_app; .\p0_step1_list_candidates.ps1

$root = "C:\apex_app"
$fe   = "$root\apex_finance"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  APEX P0 - Cleanup Candidate List"      -ForegroundColor Cyan
Write-Host "  DRY RUN - Nothing will be deleted"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$found    = @()
$notFound = @()

$group1 = @(
    "$fe\lib\screens\account\archive_screen.dart.bak",
    "$fe\lib\screens\clients\client_onboarding_wizard.dart.bak",
    "$fe\lib\screens\marketplace\service_catalog_screen.dart.bak",
    "$fe\lib\screens\tasks\audit_service_screen.dart.bak",
    "$fe\lib\main_backup_p3.dart",
    "$fe\lib\main_original_working.dart"
)

Write-Host "[Group 1] .bak / old backup files (6)" -ForegroundColor Yellow
foreach ($f in $group1) {
    if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        Write-Host "  FOUND  $f  [$sz bytes]" -ForegroundColor Green
        $found += $f
    } else {
        Write-Host "  SKIP   $f  [not found]" -ForegroundColor DarkGray
        $notFound += $f
    }
}

$group2 = @(
    "$fe\lib\api_config.dart",
    "$fe\test\widget_test.dart.disabled",
    "$fe\apply_subscription_extract.py",
    "$fe\fix_main.py",
    "$fe\fix_notif.py",
    "$fe\requirements.txt",
    "$fe\apex_result.json",
    "$fe\files.zip"
)

Write-Host ""
Write-Host "[Group 2] Duplicate / temp frontend files (8)" -ForegroundColor Yellow
foreach ($f in $group2) {
    if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        Write-Host "  FOUND  $f  [$sz bytes]" -ForegroundColor Green
        $found += $f
    } else {
        Write-Host "  SKIP   $f  [not found]" -ForegroundColor DarkGray
        $notFound += $f
    }
}

$group3_names = @(
    "all_api_routes.txt", "all_config_files.txt", "all_dart_code.txt",
    "all_db_tables.txt", "all_flutter_screens.txt", "all_migrations.txt",
    "all_python_code.txt", "all_schemas.txt", "apex_api.txt",
    "apex_backend.txt", "apex_broken.txt", "apex_config.txt",
    "apex_env.txt", "apex_main.txt", "apex_openapi.txt",
    "apex_screens.txt", "full_file_tree.txt", "tree_structure.txt",
    "MIGRATION.md"
)

Write-Host ""
Write-Host "[Group 3] Documentation / export files in root (19)" -ForegroundColor Yellow
foreach ($name in $group3_names) {
    $f = "$root\$name"
    if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        Write-Host "  FOUND  $f  [$sz bytes]" -ForegroundColor Green
        $found += $f
    } else {
        Write-Host "  SKIP   $f  [not found]" -ForegroundColor DarkGray
        $notFound += $f
    }
}

$group4_files = @(
    "$root\.last_build_id",
    "$root\favicon.png",
    "$root\flutter.js",
    "$root\flutter_bootstrap.js",
    "$root\flutter_service_worker.js",
    "$root\index.html",
    "$root\main.dart.js",
    "$root\manifest.json",
    "$root\version.json"
)
$group4_dirs = @(
    "$root\assets",
    "$root\canvaskit",
    "$root\icons"
)

Write-Host ""
Write-Host "[Group 4] Root build artifacts (9 files + 3 dirs)" -ForegroundColor Yellow
foreach ($f in $group4_files) {
    if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        Write-Host "  FOUND  $f  [$sz bytes]" -ForegroundColor Green
        $found += $f
    } else {
        Write-Host "  SKIP   $f  [not found]" -ForegroundColor DarkGray
        $notFound += $f
    }
}
foreach ($d in $group4_dirs) {
    if (Test-Path $d -PathType Container) {
        $cnt = (Get-ChildItem $d -Recurse -File).Count
        Write-Host "  FOUND  $d\  [$cnt files inside]" -ForegroundColor Green
        $found += $d
    } else {
        Write-Host "  SKIP   $d\  [not found]" -ForegroundColor DarkGray
        $notFound += $d
    }
}

$group5 = @(
    "$root\apex_analyzer.py",
    "$root\api.py",
    "$root\financial_reports.py",
    "$root\test_engine.py"
)

Write-Host ""
Write-Host "[Group 5] Root Python files - REVIEW needed (4)" -ForegroundColor Magenta
foreach ($f in $group5) {
    if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        $ln = (Get-Content $f -ErrorAction SilentlyContinue).Count
        Write-Host "  FOUND  $f  [$sz bytes | $ln lines] NEEDS REVIEW" -ForegroundColor Magenta
        $found += $f
    } else {
        Write-Host "  SKIP   $f  [not found]" -ForegroundColor DarkGray
        $notFound += $f
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary"                                -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$fc = $found.Count
$nf = $notFound.Count
Write-Host "  Files/dirs found:     $fc" -ForegroundColor Green
Write-Host "  Already gone:         $nf" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Next: Review the list above."
Write-Host "  Then run: .\p0_step2_execute_cleanup.ps1"
Write-Host ""
