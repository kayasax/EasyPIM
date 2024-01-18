<#
      .Synopsis
       Export the settings of all roles  subscription scope where subscription = $subscriptionID
      .Description
       Convert the policy rules to csv
      .Parameter subscriptionID
       subscription ID
      .Parameter rolename
       Array of the rolename to check
      .Parameter exportFilename
       Filename of the csv
      .Example
        Export-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -filename "c:\temp\myrole.csv"
      .Link
     
      .Notes
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