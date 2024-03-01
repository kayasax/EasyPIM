<#
      .Synopsis
       Retrieve all role 
      .Description
       Get all roles then for each get the policy
      .Parameter tenantID
       Scope to look at
      .Example
        PS> Get-Entrarole -tenantID $tenantID

        Get all roles 
      .Link
     
      .Notes
#>
function Get-Entrarole {
  [CmdletBinding()]
  param (
      [Parameter()]
      [string]
      $tenantID
  )
    $tenantID = $script:tenantID
    $endpoint="roleManagement/directory/roleDefinitions?`$select=displayname"

    write-verbose "Getting All Policies at $endpoint"
    $response = invoke-graph -Endpoint $endpoint 
    
    $roles = $response | ForEach-Object {
        $_.value.displayname
    }
    return $roles
}
