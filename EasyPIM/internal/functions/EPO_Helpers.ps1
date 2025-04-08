function Test-PIMGroupValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipPIMCheck
    )
    
    try {
        $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$GroupId"
        $null = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        Write-Verbose "Group $GroupId exists and is accessible"
        
        if (-not $SkipPIMCheck) {
            if (-not (Test-GroupEligibleForPIM -GroupId $GroupId)) {
                Write-Warning "Group $GroupId is not eligible for PIM management, skipping"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Warning "Group $GroupId does not exist, skipping"
        return $false
    }
}