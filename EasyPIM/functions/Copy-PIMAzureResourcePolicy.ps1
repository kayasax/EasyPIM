<#
      .Synopsis
        Copy the setting of roles $copyfrom to the role $rolename
      .Description
        Copy the setting of roles $copyfrom to the role $rolename
      .Parameter tenantID
        EntraID tenant ID
      .Parameter subscriptionID
        subscription ID
      .Parameter rolename
        Array of the rolename to update
      .Parameter copyFrom
        We will copy the settings from this role to rolename
      .Example
        PS> Copy-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -copyFrom role1

        Copy settings from role role1 to the contributor and webmaster roles
      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function Copy-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $subscriptionID,

        [Parameter(Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $rolename,

        [Parameter(Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $copyFrom,

        [System.String[]]
        $scope=""
    )
    try {
        $script:tenantID = $tenantID
        Write-Verbose "Copy-PIMAzureResourcePolicy start with parameters: tenantID => $tenantID subscription => $subscriptionID, rolename=> $rolename, copyfrom => $copyFrom"
        if($scope -eq ""){
          $scope = "subscriptions/$subscriptionID"
        }
       
        $config2 = get-config $scope $copyFrom $true
        
        $rolename | ForEach-Object {
            $config = get-config $scope $_
            Log "Copying settings from $copyFrom to $_"
            [string]$policyID = $config.policyID
            $policyID = $policyID.Trim()
            Update-Policy $policyID $config2
        }
    }
    catch {
        MyCatch $_
    }
        
}
