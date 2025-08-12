[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$TenantId,
    [Parameter()][string]$SubscriptionId,
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [switch]$FailOnDrift
)

if (-not (Get-Command Test-PIMPolicyDrift -ErrorAction SilentlyContinue)) {
    $modulePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'EasyPIM' 'EasyPIM.psd1'
    try { Import-Module $modulePath -ErrorAction Stop } catch { throw "Failed to import module from ${modulePath}: $($_.Exception.Message)" }
    if (-not (Get-Command Test-PIMPolicyDrift -ErrorAction SilentlyContinue)) {
        $fnPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'EasyPIM' 'internal' 'functions' 'Test-PIMPolicyDrift.ps1'
        if (Test-Path $fnPath) { . $fnPath }
    }
}

Write-Host "🔍 (Test Harness) Verifying PIM policies from config: $ConfigPath" -ForegroundColor Cyan
$results = Test-PIMPolicyDrift -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigPath $ConfigPath -FailOnDrift:$FailOnDrift -PassThru
if ($results.Count -eq 0) { Write-Host "⚠️ No policies discovered in config (nothing compared)." -ForegroundColor Yellow }
else {
    $drift = $results | Where-Object Status -in 'Drift','Error'
    if ($drift) {
        Write-Host "❌ Drift detected in $($drift.Count) policy item(s)." -ForegroundColor Yellow
        if ($FailOnDrift) { exit 1 }
    } else {
        Write-Host "✅ All compared policy fields match expected values." -ForegroundColor Green
    }
}
