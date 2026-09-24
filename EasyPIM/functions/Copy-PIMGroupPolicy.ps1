<#
      .Synopsis
        Copy the PIM policy settings of group $copyFrom to the groups in $groupID
      .Description
        Copy the PIM policy settings of group $copyFrom to the groups in $groupID
      .Parameter tenantID
        EntraID tenant ID
      .Parameter groupID
        Array of group IDs that will receive the copied settings
      .Parameter type
        owner or member
      .Parameter copyFrom
        The group ID whose settings will be copied
      .Example
        PS> Copy-PIMGroupPolicy -tenantID $tenantID -groupID "group2-id","group3-id" -type member -copyFrom "group1-id"

        Copy the member policy settings from group1 to group2 and group3
      .Link

      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function Copy-PIMGroupPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        # Array of group IDs to update
        $groupID,

        [Parameter(Mandatory = $true)]
        [System.String]
        # owner or member
        $type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Group ID to copy settings from
        $copyFrom
    )
    try {
        $script:tenantID = $tenantID
        Write-Verbose "Copy-PIMGroupPolicy start with parameters: tenantID => $tenantID, groupID => $groupID, type => $type, copyFrom => $copyFrom"

        # Use unique temp files to avoid collisions
        $exportPath  = Join-Path $env:TEMP ("pimgroup_{0}.csv" -f ([guid]::NewGuid()))
        $newPathBase = Join-Path $env:TEMP ("pimgroup_new_{0}" -f ([guid]::NewGuid()))

        Export-PIMGroupPolicy -tenantID $tenantID -groupID $copyFrom -type $type -path $exportPath
        $c = Import-Csv $exportPath

        $groupID | ForEach-Object {
            $targetGroupID = $_
            # Get the policy ID for the target group
            $config = get-GroupConfig $targetGroupID $type
            if ($null -eq $config) {
                Write-Warning "No PIM policy found for group $targetGroupID ($type), skipping."
                return
            }
            Log "Copying $type policy settings from $copyFrom to $targetGroupID"
            [string]$policyID = $config.PolicyID
            $policyID = $policyID.Trim()

            # Create a per-iteration copy of the row to avoid mutating the shared object
            $row = $c | Select-Object *
            $row.PolicyID = $policyID
            $row.GroupID  = $targetGroupID
            $newPath = "$newPathBase.csv"
            $row | Export-Csv -Path $newPath -NoTypeInformation

            Import-PIMGroupPolicy -tenantID $tenantID -path $newPath

            if (Test-Path $newPath) { Remove-Item $newPath -Force -ErrorAction SilentlyContinue }
        }
        if ($exportPath -and (Test-Path $exportPath)) { Remove-Item $exportPath -Force -ErrorAction SilentlyContinue }
    }
    catch {
        MyCatch $_
    }
}
