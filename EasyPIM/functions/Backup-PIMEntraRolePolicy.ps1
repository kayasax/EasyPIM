<#
    .Synopsis
    Export PIM settings of all roles  to a csv file.
    Use the path parameter to specify the csv file, if not specified default filename
    will be %appdata%\powershell\EasyPIM\Exports\BACKUP_EntraRole_<date>.csv

    .Description
    Convert the policy rules to a csv file

    .Example
    PS> Export-PIMEntraRolePolicy -tennantID $tenantID -path "c:\temp\myrole.csv"

    Export settings of all roles to file c:\temp\myrole.csv

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM

#>
function Backup-PIMEntraRolePolicy {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 2)]
        [System.String]
        # Filename of the csv to generate
        $path

    )
    try {
        $script:tenantID = $tenantID
        $exports = @()

        $roles=get-entraRole

        $roles | ForEach-Object {
            log "exporting $_ role settings"
            #write-verbose  $_
            $exports += get-EntraRoleconfig $_.Trim()
        }
        $date = get-date -Format FileDateTime
        if (!($path)) { $path = "$script:_LogPath\EXPORTS\BACKUP_EntraRole_$date.csv" }
        log "exporting to $path"
        $exportPath = Split-Path $path -Parent
        #create export folder if no exist
        if ( !(test-path  $path) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }

        $exports | Select-Object * | ConvertTo-Csv | out-file $path
    }
    catch {
        MyCatch $_
    }
}
