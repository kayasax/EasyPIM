<#
    .Synopsis
        Import the settings from the csv file $path
    .Description
        Convert the csv back to policy rules
    .Parameter tenantID
        Entra ID Tenant ID
    .Parameter Path
        path to the csv file
    .Example
        PS> Import-PIMEntraRolePolicy -tenantID $tenantID -path "c:\temp\myrole.csv"

        Import settings from file c:\temp\myrole.csv
     
    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Import-PIMEntraRolePolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $TenantID,

        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )
    try{
    
    $script:tenantID = $TenantID
       
    #load settings
    Write-Verbose "Importing settings from $path"
    if ($PSCmdlet.ShouldProcess($path, "Importing policy from")) {
        Import-EntraRoleSettings $Path
    }
    Log "Success, exiting."
    }
    catch {
        Mycatch $_
    }
}