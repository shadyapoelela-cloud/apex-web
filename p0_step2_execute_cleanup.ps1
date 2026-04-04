# APEX P0 - Step 2: Execute Cleanup
# PREREQUISITE: Run p0_step1_list_candidates.ps1 first!
# Usage: cd C:\apex_app; .\p0_step2_execute_cleanup.ps1

$root = "C:\apex_app"
$fe   = "$root\apex_finance"

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "  APEX P0 - Execute Cleanup"              -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# Safety: Git commit before cleanup
Write-Host "[SAFETY] Creating git backup commit..." -ForegroundColor Yellow
Set-Location $root
git add -A 2>$null
git commit -m "P0-BACKUP: pre-cleanup snapshot" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Backup commit created. Revert with: git revert HEAD" -ForegroundColor Green
} else {
    Write-Host "  Nothing to commit or git error - proceeding." -ForegroundColor DarkGray
}

$deleted = 0
$failed  = 0
$skipped = 0

function SafeDel {
    param([string]$Path)
    if (Test-Path $Path -PathType Leaf) {
        try {
            Remove-Item $Path -Force -ErrorAction Stop
            Write-Host "  DELETED  $Path" -ForegroundColor Green
            $script:deleted++
        } catch {
            Write-Host "  FAILED   $Path" -ForegroundColor Red
            $script:failed++
        }
    } else {
        $script:skipped++
    }
}

function SafeDelDir {
    param([string]$Path)
    if (Test-Path $Path -PathType Container) {
        try {
            Remove-Item $Path -Recurse -Force -ErrorAction Stop
            Write-Host "  DELETED  $Path\" -ForegroundColor Green
            $script:deleted++
        } catch {
            Write-Host "  FAILED   $Path\" -ForegroundColor Red
            $script:failed++
        }
    } else {
        $script:skipped++
    }
}


# [1/5] .bak backup files
Write-Host ""
Write-Host "[1/5] Deleting .bak / old backup files..." -ForegroundColor Yellow

SafeDel "$fe\lib\screens\account\archive_screen.dart.bak"
SafeDel "$fe\lib\screens\clients\client_onboarding_wizard.dart.bak"
SafeDel "$fe\lib\screens\marketplace\service_catalog_screen.dart.bak"
SafeDel "$fe\lib\screens\tasks\audit_service_screen.dart.bak"
SafeDel "$fe\lib\main_backup_p3.dart"
SafeDel "$fe\lib\main_original_working.dart"


# [2/5] Duplicate / temp frontend files
Write-Host ""
Write-Host "[2/5] Deleting duplicate / temp frontend files..." -ForegroundColor Yellow

SafeDel "$fe\lib\api_config.dart"
SafeDel "$fe\test\widget_test.dart.disabled"
SafeDel "$fe\apply_subscription_extract.py"
SafeDel "$fe\fix_main.py"
SafeDel "$fe\fix_notif.py"
SafeDel "$fe\requirements.txt"
SafeDel "$fe\apex_result.json"
SafeDel "$fe\files.zip"


# [3/5] Documentation exports in root
Write-Host ""
Write-Host "[3/5] Deleting documentation exports in root..." -ForegroundColor Yellow

$docFiles = @(
    "all_api_routes.txt", "all_config_files.txt", "all_dart_code.txt",
    "all_db_tables.txt", "all_flutter_screens.txt", "all_migrations.txt",
    "all_python_code.txt", "all_schemas.txt", "apex_api.txt",
    "apex_backend.txt", "apex_broken.txt", "apex_config.txt",
    "apex_env.txt", "apex_main.txt", "apex_openapi.txt",
    "apex_screens.txt", "full_file_tree.txt", "tree_structure.txt",
    "MIGRATION.md"
)
foreach ($name in $docFiles) {
    SafeDel "$root\$name"
}


# [4/5] Root build artifacts
Write-Host ""
Write-Host "[4/5] Deleting root build artifacts..." -ForegroundColor Yellow

SafeDel "$root\.last_build_id"
SafeDel "$root\favicon.png"
SafeDel "$root\flutter.js"
SafeDel "$root\flutter_bootstrap.js"
SafeDel "$root\flutter_service_worker.js"
SafeDel "$root\index.html"
SafeDel "$root\main.dart.js"
SafeDel "$root\manifest.json"
SafeDel "$root\version.json"

SafeDelDir "$root\assets"
SafeDelDir "$root\canvaskit"
SafeDelDir "$root\icons"


# [5/5] Root Python files (auto-check)
Write-Host ""
Write-Host "[5/5] Checking root Python files..." -ForegroundColor Magenta

$pyChecks = @(
    @("$root\apex_analyzer.py",    "$root\app\services"),
    @("$root\api.py",              "$root\app\main.py"),
    @("$root\financial_reports.py", "$root\app\services"),
    @("$root\test_engine.py",      "$root\tests")
)

foreach ($pair in $pyChecks) {
    $pyFile = $pair[0]
    $target = $pair[1]
    if (Test-Path $pyFile) {
        $sz = (Get-Item $pyFile).Length
        if ($sz -lt 5000 -and (Test-Path $target)) {
            Write-Host "  AUTO-DEL $pyFile  [small + target exists]" -ForegroundColor Green
            Remove-Item $pyFile -Force
            $deleted++
        } elseif ($sz -lt 500) {
            Write-Host "  AUTO-DEL $pyFile  [trivial: $sz bytes]" -ForegroundColor Green
            Remove-Item $pyFile -Force
            $deleted++
        } else {
            Write-Host "  KEPT     $pyFile  [$sz bytes] manual review needed" -ForegroundColor Magenta
            Write-Host "           Compare with: $target" -ForegroundColor DarkGray
        }
    }
}


# Git commit after cleanup
Write-Host ""
Write-Host "[GIT] Committing cleanup..." -ForegroundColor Yellow
Set-Location $root
git add -A
git commit -m "P0: project cleanup - removed $deleted backup/temp/duplicate/doc files"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Cleanup committed." -ForegroundColor Green
} else {
    Write-Host "  Git commit issue - check manually." -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  P0 Cleanup Complete"                    -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deleted:  $deleted" -ForegroundColor Green
Write-Host "  Failed:   $failed" -ForegroundColor DarkGray
Write-Host "  Skipped:  $skipped [already gone]" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Next: .\p0_step3_verify.ps1"
Write-Host ""
