﻿<#
      .Synopsis
        Copy the setting of roles $copyfrom to the role $rolename
      .Description
        Copy the setting of roles $copyfrom to the role $rolename
      .Parameter tenantID
        EntraID tenant ID
      
      .Parameter rolename
        Array of the rolename to update
      .Parameter copyFrom
        We will copy the settings from this role to rolename
      .Example
        PS> Copy-PIMEntraRolePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -copyFrom role1

        Copy settings from role role1 to the contributor and webmaster roles
      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function Copy-PIMEntraRolePolicy {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Tenant ID
        $tenantID,

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
        Write-Verbose "Copy-PIMEntraRolePolicy start with parameters: tenantID => $tenantID subscription => $subscriptionID, rolename=> $rolename, copyfrom => $copyFrom"
              
        export-PIMEntraRolepolicy  -tenantid $tenantID -rolename $copyFrom -path "$env:TEMP\role.csv"
        $c=import-csv "$env:TEMP\role.csv"
        
        $rolename | ForEach-Object {
          #get policy id and replace it in the csv before importing it
            $config = get-EntraRoleconfig  $_
            write-verbose "ID= $($config.PolicyID)"
            Log "Copying settings from $copyFrom to $_"
            [string]$policyID = $config.PolicyID
            $policyID = $policyID.Trim()
            write-verbose "before:$($c.policyID)"
            $c.PolicyID = $policyID
            $newconf = $c |export-csv -Path "$env:TEMP\newrole.csv" -NoTypeInformation

            import-PIMEntraRolepolicy -tenantid $tenantID  -path "$env:TEMP\newrole.csv"

            Remove-Item "$env:TEMP\role.csv" -Force
            Remove-Item "$env:TEMP\newrole.csv" -Force
        }
    }
    catch {
        MyCatch $_
    }
        
}
