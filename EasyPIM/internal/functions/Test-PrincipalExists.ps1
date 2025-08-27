<#
.SYNOPSIS
Test if a principal (user or group) exists in Azure AD

.DESCRIPTION
Verifies if a principal ID exists in Azure Active Directory by attempting to retrieve it via Microsoft Graph API

.PARAMETER PrincipalId
The Object ID (GUID) of the principal to test

.EXAMPLE
Test-PrincipalExists -PrincipalId "12345678-1234-1234-1234-123456789012"

.NOTES
Author: Loïc MICHEL
Homepage: https://github.com/kayasax/EasyPIM
#>
function Test-PrincipalExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId
    )

    Write-Verbose "Testing if principal $PrincipalId exists"

    try {
        # Try to get the principal from Graph API
        $null = invoke-graph -Endpoint "directoryObjects/$PrincipalId" -ErrorAction Stop
        Write-Verbose "Principal $PrincipalId exists"
        return $true
    } catch {
        Write-Verbose "Principal $PrincipalId does not exist or is not accessible: $($_.Exception.Message)"
        return $false
    }
}
