<#
.SYNOPSIS
    Creates a privacy-protected identifier for telemetry from tenant ID

.DESCRIPTION
    Generates a SHA256 hash of the tenant ID combined with a salt to create
    a consistent but privacy-protected identifier for telemetry purposes.
    Never transmits the actual tenant ID.

.PARAMETER TenantId
    The Azure AD tenant ID to create an identifier for

.EXAMPLE
    Get-TelemetryIdentifier -TenantId "12345678-1234-1234-1234-123456789012"
    Returns a SHA256 hash for privacy-protected telemetry identification

.NOTES
    Author: Loïc MICHEL
    Privacy: Always encrypts tenant ID, no clear-text transmission
#>
function Get-TelemetryIdentifier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId
    )

    try {
        # Hardcoded salt for consistent hashing (non-configurable security practice)
        $Salt = "EasyPIM-Privacy-Salt-2025-PostHog"
        $StringToHash = "$TenantId-$Salt"

        # Create SHA256 hash for privacy protection
        $HashedBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($StringToHash)
        )

        $HashedIdentifier = [System.BitConverter]::ToString($HashedBytes).Replace("-", "").ToLower()

        Write-Verbose "Generated privacy-protected telemetry identifier (SHA256)"
        return $HashedIdentifier
    }
    catch {
        Write-Verbose "Failed to generate telemetry identifier: $($_.Exception.Message)"
        return $null
    }
}
