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
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(ParameterSetName = 'Default',Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $subscriptionID,
        
        [Parameter(ParameterSetName = 'Scope',Position = 1, Mandatory = $true)]
        [System.String]
        $scope,

        [Parameter(Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $rolename,

        [Parameter(Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $copyFrom
    )
    try {
        $script:tenantID = $tenantID
        Write-Verbose "Copy-PIMAzureResourcePolicy start with parameters: tenantID => $tenantID subscription => $subscriptionID, rolename=> $rolename, copyfrom => $copyFrom"
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
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
