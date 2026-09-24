<#
      .Synopsis
        Export the PIM policy settings of a group to CSV
      .Description
        Convert the group policy rules to CSV
      .Parameter tenantID
        EntraID tenant ID
      .Parameter groupID
        Array of group IDs to export
      .Parameter groupName
        Search for the group by name
      .Parameter type
        owner or member
      .Parameter path
        path of the csv to generate, if not specified default filename will be %appdata%\powershell\EasyPIM\Exports\PIMGroups_<datetime>.csv
      .Example
        PS> Export-PIMGroupPolicy -tenantID $tenantID -groupID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -type member -path "c:\temp\group.csv"

        Export the member policy settings of the specified group to file c:\temp\group.csv
      .Example
        PS> Export-PIMGroupPolicy -tenantID $tenantID -groupName "MyGroup" -type owner -path "c:\temp\group.csv"

        Export the owner policy settings of the group named "MyGroup" to file c:\temp\group.csv
      .Link

      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Export-PIMGroupPolicy {
    [CmdletBinding(DefaultParameterSetName='ByID')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(ParameterSetName = 'ByID', Position = 1)]
        [System.String[]]
        # Array of group IDs
        $groupID,

        [Parameter(ParameterSetName = 'ByName', Position = 1)]
        [System.String]
        # Group name to search for
        $groupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        # owner or member
        $type,

        [Parameter(Position = 3)]
        [System.String]
        # Path of the csv to generate
        $path
    )
    try {
        $script:tenantID = $tenantID

        Write-Verbose "Export-PIMGroupPolicy start with parameters: tenantID => $tenantID, groupID => $groupID, groupName => $groupName, type => $type, path => $path"

        if ($PSBoundParameters.ContainsKey('groupName')) {
            $endpoint = "/groups?`$filter=startswith(displayName,'$($groupName)')"
            $response = invoke-graph -Endpoint $endpoint
            if ($null -eq $groupID) { $groupID = @() }
            $groupID += $response.value.id
        }

        if (-not ($PSBoundParameters.ContainsKey('groupID')) -and -not ($PSBoundParameters.ContainsKey('groupName'))) {
            throw "You must provide a groupID or a groupName"
        }

        $exports = @()

        $groupID | ForEach-Object {
            $config = get-GroupConfig $_ $type
            if ($null -ne $config) {
                # Store GroupID alongside config for import round-tripping
                $config | Add-Member -MemberType NoteProperty -Name 'GroupID' -Value $_ -Force
                $exports += $config
            }
        }

        $date = get-date -Format FileDateTime
        if (!($path)) { $path = "$script:_logPath\EXPORTS\PIMGroups_$date.csv" }
        log "exporting to $path"
        $exportPath = Split-Path $path -Parent
        if ( !(test-path $path) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        $exports | Select-Object * | ConvertTo-Csv | out-file $path
        log "Success! Script ended normally"
    }
    catch {
        MyCatch $_
    }
}
