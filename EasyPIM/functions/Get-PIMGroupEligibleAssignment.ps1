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
    PS> Get-PIMGroupEligibleAssignment -tenantID $tid -groupID $gID

    List eligible assignments

    .Example
    PS> Get-PIMGroupEligibleAssignment -tenantID $tid -groupID $gID -userPrincipalName "user@domain.com"

    List eligible assignments for a specific user by UPN


    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>

function Get-PIMGroupEligibleAssignment {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        # select the most usefull info only
        [switch]$summary,
        [Parameter(Mandatory = $true)]
        [string]$groupID,
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
                Write-Output "0 eligible assignment(s) found for group $groupID in tenant $tenantID"
                return @()
            }
        }

        # Build Graph API filter for better performance
        $graphFilters = @("groupId eq '$groupID'")  # groupID is always required

        # Use resolved principal ID if we got one from userPrincipalName
        if ($resolvedPrincipalId) {
            $graphFilters += "principal/id eq '$resolvedPrincipalId'"
        }
        elseif ($PSBoundParameters.Keys.Contains('principalName')) {
            $graphFilters += "startswith(principal/displayName,'$principalName')"
        }

        $filter = $graphFilters -join ' and '

        $endpoint = "identityGovernance/privilegedAccess/group/eligibilitySchedules?`$expand=principal"
        $response = invoke-graph -Endpoint $endpoint -Filter $filter
        $resu = @()
        $response.value | ForEach-Object {

            $r = @{
                #"rolename"         = $_.roledefinition.displayName
                ##"roleid"           = $_.roledefinition.id
                "principalname"    = $_.principal.displayName
                "principalid"      = $_.principal.id
                "principalEmail"   = $_.principal.mail
                "startDateTime"    = $_.scheduleInfo.startDateTime
                "endDateTime"      = $_.scheduleInfo.expiration.endDateTime
               #"directoryScopeId" = $_.directoryScopeId
                "memberType"       = $_.accessId
                "assignmentType"   = $_.memberType
                #"activatedUsing"=$_.activatedUsing
                "principaltype"    = $_.principal."@odata.type"
                "id"               = $_.id
            }
            $resu += New-Object PSObject -Property $r


        }

        if ($PSBoundParameters.Keys.Contains('summary')) {
            $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, PrincipalType, startDateTime, endDateTime, directoryScopeId        }

        # Note: keeping minimal PowerShell filtering for edge cases
        if ($PSBoundParameters.Keys.Contains('principalid')) {
            $resu = $resu | Where-Object { $_.principalid -eq $principalid }
        }

        # No need for PowerShell filtering for userPrincipalName since it's resolved to object ID
        # and filtered efficiently at the Graph API level

        Write-Output "$($resu.Count) eligible assignment(s) found for group $groupID in tenant $tenantID"
        return $resu
    }
    catch {
        MyCatch $_
    }
}
