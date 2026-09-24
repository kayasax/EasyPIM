<#
    .Synopsis
        Import PIM group policy settings from a CSV file
    .Description
        Convert the CSV back to group policy rules and apply them
    .Parameter tenantID
        Entra ID Tenant ID
    .Parameter Path
        path to the csv file
    .Example
        PS> Import-PIMGroupPolicy -tenantID $tenantID -path "c:\temp\mygroup.csv"

        Import group policy settings from file c:\temp\mygroup.csv

    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Import-PIMGroupPolicy {
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
    try {
        $script:tenantID = $TenantID

        Write-Verbose "Importing group policy settings from $path"
        if ($PSCmdlet.ShouldProcess($path, "Importing group policy from")) {
            Import-GroupSettings $Path
        }
        Log "Success, exiting." -noEcho
    }
    catch {
        Mycatch $_
    }
}
