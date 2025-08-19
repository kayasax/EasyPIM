<#
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
        PS> Copy-PIMEntraRolePolicy -tenantID $tenantID -rolename contributor,webmaster -copyFrom role1

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

  # Use unique temp files to avoid collisions and allow multi-role processing
  $exportPath = Join-Path $env:TEMP ("role_{0}.csv" -f ([guid]::NewGuid()))
  $newPathBase = Join-Path $env:TEMP ("newrole_{0}" -f ([guid]::NewGuid()))

  export-PIMEntraRolepolicy -tenantid $tenantID -rolename $copyFrom -path $exportPath
  $c = Import-Csv $exportPath

        $rolename | ForEach-Object {
          #get policy id for current role and replace it in the csv before importing it
            $config = get-EntraRoleconfig  $_
            write-verbose "ID= $($config.PolicyID)"
            Log "Copying settings from $copyFrom to $_"
            [string]$policyID = $config.PolicyID
            $policyID = $policyID.Trim()
      write-verbose "before:$($c.policyID)"
            $c.PolicyID = $policyID
      $newPath = "$newPathBase.csv"
      $c | Export-Csv -Path $newPath -NoTypeInformation

      import-PIMEntraRolepolicy -tenantid $tenantID -path $newPath

      # Cleanup per-iteration file safely
      if (Test-Path $newPath) { Remove-Item $newPath -Force -ErrorAction SilentlyContinue }
        }
  # Cleanup exported CSV once after processing all roles, guarded
  if ($exportPath -and (Test-Path $exportPath)) { Remove-Item $exportPath -Force -ErrorAction SilentlyContinue }
    }
    catch {
        MyCatch $_
    }

}
