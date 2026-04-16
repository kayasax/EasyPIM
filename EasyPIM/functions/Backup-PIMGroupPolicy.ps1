<#
    .Synopsis
    Export PIM policy settings of all PIM-enabled groups to a CSV file.
    Use the path parameter to specify the CSV file; if not specified the default filename
    will be %appdata%\powershell\EasyPIM\Exports\BACKUP_PIMGroups_<date>.csv

    .Description
    Retrieve policy settings for all PIM-enabled groups (both member and owner roles)
    and export them to a CSV file for backup or later restoration via Import-PIMGroupPolicy.

    .Parameter tenantID
        Entra ID Tenant ID

    .Parameter path
        Path to the CSV file to generate

    .Example
    PS> Backup-PIMGroupPolicy -tenantID $tenantID -path "c:\temp\groups_backup.csv"

    Export settings of all PIM-enabled groups to file c:\temp\groups_backup.csv

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM

#>
function Backup-PIMGroupPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 1)]
        [System.String]
        # Path to the csv to generate
        $path
    )
    try {
        $script:tenantID = $tenantID
        $exports = @()

        # Retrieve all PIM group policy assignments
        $endpoint = "policies/roleManagementPolicyAssignments?`$filter=scopeType eq 'Group'"
        $response = invoke-graph -Endpoint $endpoint
        $assignments = $response.value

        if ($null -eq $assignments -or $assignments.Count -eq 0) {
            Write-Warning "No PIM-enabled group policy assignments found in this tenant."
        }
        else {
            # Group assignments by scopeId (groupID) and roleDefinitionId (member/owner)
            $assignments | ForEach-Object {
                $gid  = $_.scopeId
                $type = $_.roleDefinitionId  # 'member' or 'owner'
                log "exporting group $gid ($type) policy settings"
                try {
                    $config = get-GroupConfig $gid $type
                    if ($null -ne $config) {
                        $config | Add-Member -MemberType NoteProperty -Name 'GroupID' -Value $gid -Force
                        $exports += $config
                    }
                }
                catch {
                    Write-Warning "Skipping group $gid ($type): $($_.Exception.Message)"
                }
            }
        }

        $date = get-date -Format FileDateTime
        if (!($path)) { $path = "$script:_LogPath\EXPORTS\BACKUP_PIMGroups_$date.csv" }
        log "exporting to $path"
        $exportPath = Split-Path $path -Parent
        if ( !(test-path $exportPath) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }

        $exports | Select-Object * | ConvertTo-Csv | out-file $path
    }
    catch {
        MyCatch $_
    }
}
