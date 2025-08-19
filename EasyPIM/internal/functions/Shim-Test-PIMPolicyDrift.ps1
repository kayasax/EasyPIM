<#!
 Shim file retained for backward compatibility. Does NOT define Test-PIMPolicyDrift.
 The public exported function now lives in functions/Test-PIMPolicyDrift.ps1.
 If this shim is dot-sourced directly (legacy usage), we just warn if the function
 isn't already available from the module import.
#>
if (-not (Get-Command -Name Test-PIMPolicyDrift -ErrorAction SilentlyContinue)) {
    Write-Warning 'Test-PIMPolicyDrift not found. Import the EasyPIM module to load the public implementation.'
}
