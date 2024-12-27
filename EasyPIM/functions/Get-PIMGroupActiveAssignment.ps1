<#
    .Synopsis
    List active assignements for a group
    .Description
    Active assignment does not require to activate their role. https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0&tabs=http
    .Parameter tenantID
    EntraID tenant ID
    .PARAMETER groupID
    The group id to check
    .PARAMETER memberType
    Filter results by memberType (owner or member)
    .PARAMETER principalName
    Filter results by principalName starting with the given value
    .Parameter summary
    When enabled will return the most useful information only
    .Example
    PS> Get-PIMGroupActiveAssignment -tenantID $tid -groupID $gID

    List active assignement for the group $gID
    .Example
    PS> Get-PIMGroupActiveAssignment -tenantID $tid -groupID $gID -memberType owner -principalName "loic" -summary

    Get a summary of the active assignement for the group $gID, for the owner role and for the user "loic"

    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
     
function Get-PIMGroupActiveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        [Parameter(Mandatory = $true)]
        [string]$groupID,
        [string]$memberType,
        [string]$principalName,
        [switch]$summary
    )

    try {
        $script:tenantID = $tenantID

        $endpoint = "identityGovernance/privilegedAccess/group/assignmentSchedules?`$filter=groupId eq '$groupID'&`$expand=principal
        "
        $response = invoke-graph -Endpoint $endpoint
        $resu = @()
        $response.value | ForEach-Object {
    
            $r = @{
                "principalname"    = $_.principal.displayName
                "principalid"      = $_.principal.id
                "principalEmail"   = $_.principal.mail
                "startDateTime"    = $_.scheduleInfo.startDateTime
                "endDateTime"      = $_.scheduleInfo.expiration.endDateTime
                "memberType"       = $_.accessId
                "assignmentType"   = $_.memberType
                "principaltype"    = $_.principal."@odata.type"
                "id"               = $_.id
            }
            $resu += New-Object PSObject -Property $r
    
  
        }

        if ($PSBoundParameters.Keys.Contains('summary')) {
            $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, PrincipalType, startDateTime, endDateTime, directoryScopeId
        }

        if ($PSBoundParameters.Keys.Contains('principalid')) {
            $resu = $resu | Where-Object { $_.principalid -eq $principalid }
        }

        if ($PSBoundParameters.Keys.Contains('memberType')) {
            $resu = $resu | Where-Object { $_.memberType -eq $memberType }
        }
        if($PSBoundParameters.Keys.Contains('principalName')){
            $resu = $resu | Where-Object { $_.principalName -match $principalName }
        }

        return $resu
    }
    catch {
        MyCatch $_
    }
}