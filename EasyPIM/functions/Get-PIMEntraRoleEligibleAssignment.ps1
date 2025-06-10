<#
    .Synopsis
    List of PIM Entra Role active assignement
    .Description
    Active assignment does not require to activate their role. https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0&tabs=http
    .Parameter tenantID
    EntraID tenant ID
    .Parameter summary
    When enabled will return the most useful information only
    .PARAMETER rolename
    Filter by rolename
    .PARAMETER principalid
    Filter by principalid    .PARAMETER userPrincipalName
    Filter by userPrincipalName (UPN). Will resolve to object ID for efficient Graph API filtering.    .Example
    PS> Get-PIMEntraRoleEligibleAssignment -tenantID $tid

    List eligible assignments

    .Example
    PS> Get-PIMEntraRoleEligibleAssignment -tenantID $tid -userPrincipalName "user@domain.com" -rolename "Global Administrator"

    List eligible assignments for a specific user by UPN and role


    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>

function Get-PIMEntraRoleEligibleAssignment {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        # select the most usefull info only
        [switch]$summary,
        [string]$principalid,
        [string]$rolename,
        [string]$userPrincipalName
    )    try {        $script:tenantID = $tenantID

        # Resolve userPrincipalName to object ID if provided
        $resolvedPrincipalId = $null
        if ($PSBoundParameters.Keys.Contains('userPrincipalName')) {
            try {
                Write-Verbose "Resolving userPrincipalName '$userPrincipalName' to object ID..."
                $userEndpoint = "/users/$userPrincipalName"
                $userResponse = invoke-graph -Endpoint $userEndpoint
                $resolvedPrincipalId = $userResponse.id
                Write-Verbose "Resolved to object ID: $resolvedPrincipalId"
            }
            catch {
                Write-Warning "Could not resolve userPrincipalName '$userPrincipalName': $($_.Exception.Message)"
                # Return empty result if user not found
                Write-Output "0 $rolename eligible assignment(s) found for tenant $tenantID"
                return @()
            }
        }

        # Build Graph API filter (only for supported properties)
        $graphFilters = @()

        # Use resolved principal ID if we got one from userPrincipalName, otherwise use provided principalid
        $effectivePrincipalId = if ($resolvedPrincipalId) { $resolvedPrincipalId } else { $principalid }
        if ($PSBoundParameters.Keys.Contains('principalid') -or $resolvedPrincipalId) {
            $graphFilters += "principal/id eq '$effectivePrincipalId'"
        }

        if ($PSBoundParameters.Keys.Contains('rolename')) {
            # Use tolower() for case-insensitive comparison
            $rolenameLower = $rolename.ToLower()
            $graphFilters += "tolower(roleDefinition/displayName) eq '$rolenameLower'"        }

        # Note: userPrincipalName is now resolved to object ID above for efficient Graph API filtering
        # This eliminates the need for PowerShell filtering after retrieval

        # Combine filters with 'and' operator
        $filter = if ($graphFilters.Count -gt 0) { $graphFilters -join ' and ' } else { $null }

        $endpoint = "/roleManagement/directory/roleEligibilityScheduleInstances?`$expand=roleDefinition,principal"
        $response = invoke-graph -Endpoint $endpoint -Filter $filter
        $resu = @()
        $response.value | ForEach-Object {

            $r = @{
                "rolename"         = $_.roledefinition.displayName
                "roleid"           = $_.roledefinition.id
                "principalname"    = $_.principal.displayName
                "principalid"      = $_.principal.id
                "startDateTime"    = $_.startDateTime
                "endDateTime"      = $_.endDateTime
                "directoryScopeId" = $_.directoryScopeId
                "memberType"       = $_.memberType
                "assignmentType"   = $_.assignmentType
                #"activatedUsing"=$_.activatedUsing
                "principaltype"    = $_.principal."@odata.type"
                "id"               = $_.id
            }
            $resu += New-Object PSObject -Property $r
        }

        if ($PSBoundParameters.Keys.Contains('summary')) {
            $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, @{l="principalType";e={if ($_ -match "user"){"user"}else{"group"}}}, startDateTime, endDateTime, directoryScopeId        }

        #Note this was for a demo we should not write host normally
        # need to use Write-Host since Write-Output will be counted as a result otherwise
        #Write-Host "$($resu.Count) $rolename eligible assignment(s) found for tenant $tenantID"
        return $resu


    }
    catch { Mycatch $_ }
}
