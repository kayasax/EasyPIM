<#
    .Synopsis
    Export PIM settings of all roles at the subscription scope to a csv file.
    Use the exportFilename parameter to specify the csv file, if not specified default filename
    will be %appdata%\powershell\EasyPIM\Exports
      
    .Description
    Convert the policy rules to a csv file
    
    .Example
    PS> Export-PIMAzureResourcePolicy -tennantID $tenantID -subscriptionID $subscriptionID -filename "c:\temp\myrole.csv"

    Export settings of all roles to file c:\temp\myrole.csv

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
    
#>
function Backup-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        # subscription id
        $subscriptionID,
        
        [Parameter(Position = 2)]
        [System.String]
        # Filename of the csv to generate
        $exportFilename
    )
    try {
        $script:tenantID = $tenantID
        $exports = @()
        $scope = "subscriptions/$subscriptionID"

        $policies = Get-AllPolicies $scope
        
        $policies | ForEach-Object {
            log "exporting $_ role settings"
            #write-verbose  $_
            $exports += get-config $scope $_.Trim()
        }
        $date = get-date -Format FileDateTime
        if (!($exportFilename)) { $exportFilename = "$script:_LogPath\EXPORTS\BACKUP_$date.csv" }
        log "exporting to $exportFilename"
        $exportPath = Split-Path $exportFilename -Parent
        #create export folder if no exist
        if ( !(test-path  $exportFilename) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        
        $exports | Select-Object * | ConvertTo-Csv | out-file $exportFilename
    }
    catch {
        MyCatch $_
    }
}