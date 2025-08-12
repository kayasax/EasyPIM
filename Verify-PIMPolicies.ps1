<#+
.SYNOPSIS
Verifies PIM policy settings (Azure resource roles, Entra roles, and Group roles) against an expected configuration file.

.DESCRIPTION
Loads a JSON configuration (supports comments and templates) and compares key PIM policy fields with the live tenant / subscription.
Reports drift (differences) and can optionally return a non‑zero exit code when drift is detected (FailOnDrift).

Supported config shapes:
  - Legacy arrays: AzureRolePolicies / EntraRolePolicies / GroupPolicies
  - Nested maps:   AzureRoles.Policies / EntraRoles.Policies / GroupRoles.Policies
  - PolicyTemplates block for declarative reuse (item.Template referencing a template name)

.PARAMETER TenantId
Entra tenant (Directory) ID to query.

.PARAMETER SubscriptionId
Azure subscription Id for Azure role policy verification. If omitted, Azure role policies in the config are skipped.

.PARAMETER ConfigPath
Path to the JSON policy configuration file. Supports // and /* */ comments.

.PARAMETER FailOnDrift
If supplied, the script exits with code 1 when any drift or retrieval errors are detected.

.EXAMPLE
pwsh -File .\Verify-PIMPolicies.ps1 -TenantId 00000000-0000-0000-0000-000000000000 -SubscriptionId 11111111-1111-1111-1111-111111111111 -ConfigPath .\policy.json -FailOnDrift

.EXAMPLE
pwsh -File .\Verify-PIMPolicies.ps1 -TenantId 00000000-0000-0000-0000-000000000000 -ConfigPath .\policy.json
Skips Azure role policies if none or because SubscriptionId not provided.

.NOTES
This script duplicates logic used by the test harness (tests/Verify-PIMPolicies.ps1) to provide a user facing entry point.
Keep both in sync or refactor into a shared internal function if further enhancements are made.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$TenantId,
  [Parameter()][string]$SubscriptionId,
  [Parameter(Mandatory=$true)][string]$ConfigPath,
  [switch]$FailOnDrift,
  [switch]$PassThru
)

# Ensure module imported for internal function availability
if (-not (Get-Command Test-PIMPolicyDrift -ErrorAction SilentlyContinue)) {
  try { Import-Module (Join-Path $PSScriptRoot 'EasyPIM' 'EasyPIM.psd1') -ErrorAction Stop } catch { Write-Warning "Could not auto-import EasyPIM module: $($_.Exception.Message)" }
}

Write-Host "🔍 Verifying PIM policies from config: $ConfigPath" -ForegroundColor Cyan
$results = Test-PIMPolicyDrift -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigPath $ConfigPath -FailOnDrift:$FailOnDrift -PassThru:$PassThru
if ($PassThru) { return $results }
if ($FailOnDrift -and ($results | Where-Object Status -in 'Drift','Error')) { exit 1 }