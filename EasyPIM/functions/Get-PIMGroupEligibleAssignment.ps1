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
    Filter by principalid
    .PARAMETER principalName
    Filter by principalName

    .Example
    PS> Get-PIMEntraRoleActiveAssignment -tenantID $tid

    List active assignement


    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
     
function Get-PIMGroupEligibleAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        # select the most usefull info only
        [switch]$summary,
        [Parameter(Mandatory = $true)]
        [string]$groupID,
        [string]$rolename,
        [string]$principalName
    )

    try {
        $script:tenantID = $tenantID

        $endpoint = "identityGovernance/privilegedAccess/group/eligibilitySchedules?`$filter=groupId eq '$groupID'&`$expand=principal
        "
        $response = invoke-graph -Endpoint $endpoint
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
            $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, PrincipalType, startDateTime, endDateTime, directoryScopeId
        }

        if ($PSBoundParameters.Keys.Contains('principalid')) {
            $resu = $resu | Where-Object { $_.principalid -eq $principalid }
        }

        if ($PSBoundParameters.Keys.Contains('rolename')) {
            $resu = $resu | Where-Object { $_.rolename -eq $rolename }
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