<#!
 Shim file retained for backward compatibility. Does NOT define Test-PIMPolicyDrift.
 The public exported function now lives in functions/Test-PIMPolicyDrift.ps1.
 
 This shim is disabled to prevent warnings during module import.
 The function is properly exported via the module manifest.
#>
# Shim disabled - function is available via proper module export.
# Optional guard left intentionally commented to avoid noisy logs during import:
# if (-not (Get-Command -Name Test-PIMPolicyDrift -ErrorAction SilentlyContinue)) {
#     Write-Verbose 'Test-PIMPolicyDrift is exported by the module at import time.'
# }
