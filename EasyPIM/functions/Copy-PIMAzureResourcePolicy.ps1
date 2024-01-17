<# 
      .Synopsis
       Copy the setting of roles $copyfrom to the role $rolename 
      .Description
       
      .Parameter subscriptionID 
       subscription ID
      .Parameter rolename
       Array of the rolename to update
      .Parameter copyFrom
       We will copy the settings from this role to rolename
      .Example
        Copy-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -copyFrom role1
      .Link
     
      .Notes
#>
function Copy-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $subscriptionID,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $rolename,

        [Parameter(Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $copyFrom 
    )
    try {
        Write-Verbose "Copy-PIMAzureResourcePolicy start with parameters: subscription => $subscriptionID, rolename=> $rolename, copyfrom => $copyFrom"
        Log "Copying settings from $copyFrom"
        $scope = "subscriptions/$subscriptionID"
        $config2 = get-config $scope $copyFrom $true
        
        $rolename | % {
            $config = get-config $scope $_
            [string]$policyID = $config.policyID
            $policyID = $policyID.Trim()
            Update-Policy $policyID $config2 
        }
    }
    catch {
        MyCatch $_
    }
        
}
