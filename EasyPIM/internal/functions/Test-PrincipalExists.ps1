# Add caching for directory object lookups
if (-not $script:principalCache) { $script:principalCache = @{} }
if (-not $script:principalObjectCache) { $script:principalObjectCache = @{} }

<#
.SYNOPSIS
Check whether an Entra ID directory object exists by ID.

.DESCRIPTION
Performs a lightweight GET on /directoryObjects/{id} using Microsoft Graph and caches results to reduce repeated calls.

.PARAMETER PrincipalId
The object ID (GUID) of the directory object to check.

.EXAMPLE
Test-PrincipalExists -PrincipalId $objectId
Returns $true if the object exists (HTTP 200), or $false for HTTP 404 and other handled errors.
#>
function Test-PrincipalExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param ([string]$PrincipalId)

    # Return from cache if available
    if ($script:principalCache.ContainsKey($PrincipalId)) {
        return $script:principalCache[$PrincipalId]
    }

    # Lightweight existence check using Graph request; suppress noisy NotFound throws
    try {
        if ( $null -eq (Get-MgContext) -or ( (Get-MgContext).TenantId -ne $script:tenantID ) ) {
            $scopes = @(
                "RoleManagementPolicy.ReadWrite.Directory",
                "PrivilegedAccess.ReadWrite.AzureAD",
                "RoleManagement.ReadWrite.Directory",
                "RoleManagementPolicy.ReadWrite.AzureADGroup",
                "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
                "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
                "PrivilegedAccess.ReadWrite.AzureADGroup",
                "AuditLog.Read.All",
                "Directory.Read.All")
            Connect-MgGraph -Tenant $script:tenantID -Scopes $scopes -NoWelcome | Out-Null
        }

        $graphEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
        $uri = "$graphEndpoint/v1.0/directoryObjects/$PrincipalId"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        # Cache
        $script:principalCache[$PrincipalId] = $true
        $script:principalObjectCache[$PrincipalId] = $response
        Write-Verbose "Principal $PrincipalId exists"
        return $true
    }
    catch {
        # If 404 treat as not existing silently
        $statusCode = $null
    try { $statusCode = $_.Exception.Response.StatusCode } catch { Write-Verbose "Suppressed status code extraction: $($_.Exception.Message)" }
        if ($statusCode -and ($statusCode.Value__ -eq 404 -or $statusCode -eq 404)) {
            Write-Verbose "Principal $PrincipalId does not exist (404)"
            $script:principalCache[$PrincipalId] = $false
            return $false
        }
        # Other errors propagate (cache false to avoid repeated calls)
        $script:principalCache[$PrincipalId] = $false
        Write-Verbose "Principal $PrincipalId existence check error: $($_.Exception.Message)"
        return $false
    }
}
