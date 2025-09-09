# Enhanced Test-PrincipalExists for orchestrator use - PowerShell 5.1 compatible
function Test-PrincipalExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId
    )

    Write-Verbose "Testing if principal $PrincipalId exists"

    try {
        # Use Invoke-MgGraphRequest directly to avoid function scoping issues
        $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$PrincipalId"
        $result = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        
        if ($result -and $result.id) {
            Write-Verbose "Principal $PrincipalId exists (Type: $($result.'@odata.type'))"
            return $true
        } else {
            Write-Verbose "Principal $PrincipalId returned null or invalid result"
            return $false
        }
    } catch {
        # Handle specific error cases
        $errorMessage = $_.Exception.Message
        Write-Verbose "Principal $PrincipalId validation failed: $errorMessage"
        
        # Check if it's a 404 (not found) or other Graph API error
        if ($errorMessage -match "404|NotFound|does not exist|Request_ResourceNotFound" -or
            ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 404)) {
            Write-Verbose "Principal $PrincipalId does not exist (404 Not Found)"
            return $false
        } else {
            Write-Warning "Unexpected error checking principal $PrincipalId`: $errorMessage"
            return $false
        }
    }
}
