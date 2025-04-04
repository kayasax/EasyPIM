function Test-GroupEligibleForPIM {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    
    try {
        # Get detailed group information with properties to check sync status
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=id,displayName,onPremisesSyncEnabled,groupTypes"
        $groupDetails = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        
        # Check if the group is synchronized from on-premises
        if ($groupDetails.onPremisesSyncEnabled -eq $true) {
            Write-Warning "Group $($groupDetails.displayName) ($GroupId) is synchronized from on-premises and cannot be managed by PIM"
            return $false
        }
        
        # Check if it's a Microsoft 365 group (which might have different PIM capabilities)
        if ($groupDetails.groupTypes -and $groupDetails.groupTypes -contains "Unified") {
            Write-Verbose "Group $($groupDetails.displayName) ($GroupId) is a Microsoft 365 group"
            # For now we'll consider these eligible, but you might need special handling
        }
        
        # Group is eligible for PIM
        return $true
    }
    catch {
        Write-Warning "Error checking group $GroupId eligibility for PIM: $_"
        # Default to false if we can't verify
        return $false
    }
}