# APEX Backend Launcher - validates Anthropic key then starts uvicorn
# Usage: cd C:\apex_app; .\start_backend.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "           APEX Backend Launcher (AI-enabled)                    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 1) Change to worktree
$worktree = "C:\apex_app\.claude\worktrees\relaxed-visvesvaraya-fc12ca"
if (-not (Test-Path -LiteralPath $worktree)) {
    Write-Host "[X] Worktree not found: $worktree" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Set-Location -LiteralPath $worktree
Write-Host "[OK] Working dir: $worktree" -ForegroundColor Green

# 2) Look for stored key
$storedKey = [Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY", "User")
$keyValid = $false
if ($storedKey -and $storedKey.StartsWith("sk-ant-") -and $storedKey.Length -gt 50) {
    Write-Host "[OK] Found stored ANTHROPIC_API_KEY (length: $($storedKey.Length))" -ForegroundColor Green
    $env:ANTHROPIC_API_KEY = $storedKey
    $keyValid = $true
}

if (-not $keyValid) {
    Write-Host ""
    Write-Host "[!] No valid ANTHROPIC_API_KEY stored." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Get the key from ONE of these:" -ForegroundColor White
    Write-Host "  1. Render Dashboard:"
    Write-Host "     https://dashboard.render.com/web/srv-d72djaea2pns73eugj4g/env"
    Write-Host "     Find ANTHROPIC_API_KEY, click the eye icon, copy the value"
    Write-Host "  2. Anthropic Console:"
    Write-Host "     https://console.anthropic.com/settings/keys"
    Write-Host ""
    Write-Host "The key starts with sk-ant- and is ~100+ chars long." -ForegroundColor White
    Write-Host "Paste it below (typing will be hidden - thats normal):" -ForegroundColor White
    Write-Host ""

    $secureKey = Read-Host "ANTHROPIC_API_KEY" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if (-not $key) {
        Write-Host "[X] No key entered." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    $key = $key.Trim()
    if ($key.Length -lt 50) {
        Write-Host "[X] Key too short ($($key.Length) chars). Must be real Anthropic key." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    if (-not $key.StartsWith("sk-ant-")) {
        Write-Host "[X] Key does not start with sk-ant-. Wrong value pasted?" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $key, "User")
    Write-Host "[OK] Key saved to Windows user env (wont ask again)." -ForegroundColor Green
    $env:ANTHROPIC_API_KEY = $key
}

# 3) Ping Anthropic to verify
Write-Host ""
Write-Host "-> Testing key with Anthropic API (1 request)..." -ForegroundColor Cyan
$body = @{
    model      = "claude-sonnet-4-20250514"
    max_tokens = 10
    messages   = @(@{ role = "user"; content = "Say OK" })
} | ConvertTo-Json -Depth 5 -Compress

$headers = @{
    "x-api-key"         = $env:ANTHROPIC_API_KEY
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
}

try {
    $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" -Method Post -Headers $headers -Body $body -TimeoutSec 20
    Write-Host "[OK] Key is valid. Claude says: $($resp.content[0].text)" -ForegroundColor Green
}
catch {
    $errMsg = $_.Exception.Message
    $respBody = ""
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $respBody = $_.ErrorDetails.Message }

    Write-Host "[!] Key validation check failed:" -ForegroundColor Yellow
    Write-Host "    $errMsg" -ForegroundColor Yellow

    $isAuthError = ($respBody -match "invalid.*api.key") -or ($respBody -match "authentication")
    $isNetError = ($errMsg -match "remote name") -or ($errMsg -match "resolved") -or ($errMsg -match "timed out") -or ($errMsg -match "Unable to connect") -or ($errMsg -match "SocketException")

    if ($isAuthError) {
        Write-Host ""
        Write-Host "[X] Invalid API key (authentication error). Clearing stored key..." -ForegroundColor Red
        [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $null, "User")
        Write-Host "[OK] Cleared. Rerun this script and paste a NEW key from Render or Anthropic Console." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    elseif ($isNetError) {
        Write-Host ""
        Write-Host "[i] Network error (DNS / Internet / VPN) — NOT a key problem." -ForegroundColor Cyan
        Write-Host "    Starting uvicorn anyway. Retry AI features once internet is back." -ForegroundColor Cyan
    }
    else {
        Write-Host ""
        Write-Host "[i] Unknown error — starting uvicorn anyway." -ForegroundColor Cyan
        if ($respBody) {
            Write-Host "    Response: $respBody" -ForegroundColor Yellow
        }
    }
}

# 4) Start uvicorn
Write-Host ""
Write-Host "-> Starting uvicorn on http://127.0.0.1:8000 (Ctrl+C to stop)" -ForegroundColor Cyan
Write-Host ""
py -m uvicorn app.main:app --host 127.0.0.1 --port 8000
