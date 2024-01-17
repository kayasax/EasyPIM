<# 
      .Synopsis
       Get the setting of the role $rolename at the subscription scope where subscription = $subscription
      .Description
       Get the setting of the role $rolename at the subscription scope where subscription = $subscription
      .Parameter subscriptionID 
       subscription ID
      .Parameter rolename
       Array of the rolename to check
      .Parameter copyfrom
       We will copy the settings from this role to rolename
      .Example
        Get-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster
      .Link
     
      .Notes
     #>
function Get-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        $subscriptionID,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]]
        $rolename,
        [Parameter(Position = 2)]
        $copyFrom = $null
    )
    try {
        Write-Verbose "Get-PIMAzureResourcePolicy start with parameters: subscription => $subscriptionID, rolename=> $rolename, copyfrom => $copyFrom"
        $scope = "subscriptions/$subscriptionID"
        $out = @()
        $rolename | ForEach-Object {
            
            #get curent config
            $config = get-config $scope $_
            $out += $config
        }
        return $out
    }
    catch {
        MyCatch $_
    }
    
}