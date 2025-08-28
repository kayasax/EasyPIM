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
    Filter by rolename    .PARAMETER principalid
    Filter by principalid
    .PARAMETER principalName
    Filter by principalName
    .PARAMETER userPrincipalName
    Filter by userPrincipalName (UPN). Will resolve to object ID for efficient Graph API filtering.

    .Example
    PS> Get-PIMEntraRoleActiveAssignment -tenantID $tid -rolename "testrole" -principalName "loic"

    List active assignement for role "testrole" and user name "loic"

    .Example
    PS> Get-PIMEntraRoleActiveAssignment -tenantID $tid -userPrincipalName "user@domain.com" -rolename "Global Administrator"

    List active assignments for a specific user by UPN and role


    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>

function Get-PIMEntraRoleActiveAssignment {
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
        [string]$principalName,
        [string]$userPrincipalName
    )    try {
        $script:tenantID = $tenantID

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
                Write-Verbose "0 $rolename active assignment(s) found for tenant $tenantID (user not found)"
                return @()
            }
        }

        # Build Graph API filter for better performance (only for supported properties)
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

        # Note: principalName filtering not supported by Graph API for this endpoint
        # Will be handled with PowerShell filtering after retrieval
        # Note: userPrincipalName is now resolved to object ID above for efficient Graph API filtering

        $filter = if ($graphFilters.Count -gt 0) { $graphFilters -join ' and ' } else { $null }

        $endpoint = "roleManagement/directory/roleAssignmentScheduleInstances?`$expand=roleDefinition,principal"
        $response = invoke-graph -Endpoint $endpoint -Filter $filter
        $resu = @()
        $response.value | ForEach-Object {

            $r = @{
                "rolename"         = $_.roledefinition.displayName
                "roleid"           = $_.roledefinition.id
                "principalname"    = $_.principal.displayName
                "principalid"      = $_.principal.id
                "principalEmail"   = $_.principal.mail
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
            $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, PrincipalType, startDateTime, endDateTime, directoryScopeId        }

        # Apply PowerShell filtering for principalName (not supported by Graph API for this endpoint)
        if ($PSBoundParameters.Keys.Contains('principalName')) {
            $resu = $resu | Where-Object { $_.principalName -match $principalName }
        }

        # No need for PowerShell filtering for userPrincipalName since it's resolved to object ID
        # and filtered efficiently at the Graph API level

    # Emit count as informational host output (not part of pipeline) to keep CSV exports clean
    Write-Verbose "$($resu.Count) $rolename active assignment(s) found for tenant $tenantID"
    return $resu
    }
    catch {
        MyCatch $_
    }
}
