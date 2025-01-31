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
function Copy-PIMEntraRoleEligibleAssignment {
  [CmdletBinding(DefaultParameterSetName = 'Default')]
  param (
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    # Tenant ID
    $tenantID,

    [Parameter(Position = 2, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $from,

    [Parameter(Position = 2, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $to
  )
  try {

    #convert UPN to objectID
    if ($from -match ".+@.*\..+") {
      #if this is a upn we will use graph to get the objectID
      try {
        $resu = invoke-graph -endpoint "users/$from" -Method GET -version "beta"
        $from = $resu.id
      }
      catch {
        Write-Warning "User $from not found in the tenant"
        return
      }
                
    }
         
    if ($to -match ".+@.*\..+") {
      #if this is a upn we will use graph to get the objectID
      try {
        $resu = invoke-graph -endpoint "users/$to" -Method GET -version "beta"
        $to = $resu.id
      }
      catch {
        Write-Warning "User $to not found in the tenant"
        return
      }
                
    }

    $script:tenantID = $tenantID
    Write-Verbose "Copy-PIMEntraRoleAssignment start with parameters: tenantID => $tenantID from => $from, to=> $to"
    $assignements = Get-PIMEntraRoleEligibleAssignment  -tenantid $tenantID
    #$assignements
    $assignements | Where-Object {$_.principalID -eq "$from"} | ForEach-Object {
      Write-Verbose  ">>>New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -roleName $($_.roleName) -principalID $to"
      New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -roleName $_.roleName -principalID $to
    }
        
  }
  catch {
    MyCatch $_
  }
        
}
