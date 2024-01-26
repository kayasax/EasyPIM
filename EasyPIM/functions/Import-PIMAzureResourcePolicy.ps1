<#
    .Synopsis
        Import the settings from the csv file $path
    .Description
        Convert the csv back to policy rules
    .Parameter tenantID
        Entra ID Tenant ID
    .Parameter subscriptionID
        subscription ID
    .Parameter Path
        path to the csv file
    .Example
        PS> Import-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionID -path "c:\temp\myrole.csv"

        Import settings from file c:\temp\myrole.csv
     
    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Import-PIMAzureResourcePolicy {
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
    
    $script:tenantID = $TenantID
       
    #load settings
    Write-Verbose "Importing settings from $path"
    if ($PSCmdlet.ShouldProcess($path, "Importing policy from")) {
    import-setting $Path
    }
    Log "Success, exiting."
}