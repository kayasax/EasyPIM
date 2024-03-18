<#
    .Synopsis
    Create an active assignement for the group $groupID and for the principal $principalID
    .Description
    Active assignment does not require users to activate their role. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
    .Parameter groupID
    objectID of the group
    .Parameter principalID
    objectID of the principal (user, group or service principal)
    .Parameter type
    member type (owner or member)
    .Parameter duration
    duration of the assignment, if not set we will use the maximum allowed value from the policy
    .Parameter startDateTime
    When the assignment wil begin, if not set we will use current time
    .Parameter permanent
    Use this parameter if you want a permanent assignement (no expiration)
    .Parameter justification
    justification


    .Example
    PS> New-PIMGroupActiveAssignment -tenantID $tenantID -groupID $gID -principalID $userID -type member -duration "P7D"

    Create an active assignment for the membership role of the group $gID and principal $userID starting now and using a duration of 7 days

    PS> New-PIMGroupActiveAssignment -tenantID $tenantID -groupID $gID -principalID $userID -type owner -permanent
    
    Create a permanent active assignement for the ownership role of the group $gID and principal $userID starting now
    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMGroupActiveAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        # Entra ID tenantID
        $groupID,
        
        [Parameter(Mandatory = $true)]
        [String]
        # Principal ID
        $principalID,

        [Parameter(Mandatory = $true)]
        [string]
        # the rolename for which we want to create an assigment
        $type,

        [string]
        # duration of the assignment, if not set we will use the maximum allowed value from the role policy
        $duration,

        [string]
        # stat date of assignment if not provided we will use curent time
        $startDateTime,

        [string]
        # justification (will be auto generated if not provided)
        $justification,

        [switch]
        # the assignment will not expire
        $permanent

    )
    
    try {
        $script:tenantID = $tenantID

        if ($PSBoundParameters.Keys.Contains('startDateTime')) {
            $startDateTime = get-date ([datetime]::Parse($startDateTime)).touniversaltime().addseconds(30) -f "yyyy-MM-ddTHH:mm:ssZ"
        }
        else {
            $startDateTime = get-date (get-date).touniversaltime().addseconds(30) -f "yyyy-MM-ddTHH:mm:ssZ" #we get the date as UTC (remember to add a Z at the end or it will be translated to US timezone on import)
        }
    
        write-verbose "Calculated date time start is $startDateTime"
        # 2 get role settings:
        $config = Get-PIMgroupPolicy -tenantID $tenantID -groupID $groupID -type $type

        #if permanent assignement is requested check this is allowed in the rule
        if ($permanent) {
        if ( $config.AllowPermanentActiveAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent eligible assignement, exiting"
            }
        }

        # if Duration is not provided we will take the maxium value from the role setting
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
    $duration = $config.MaximumActiveAssignmentDuration
        }
        write-verbose "assignement duration will be : $duration"

        if (!($PSBoundParameters.Keys.Contains('justification'))) {
            $justification = "Approved from EasyPIM module by  $($(get-azcontext).account)"
        }
    

        $exptype = "AfterDuration"
        #$type="afterDateTime"
        if ($permanent) {
            $exptype = "NoExpiration"
        }

        $body = '
{
    "action": "adminAssign",
    "accessID":"'+$type+'",
    "groupID":"'+$groupID+'",
    "justification": "'+ $justification + '",
    "principalId": "'+ $principalID + '",
    "scheduleInfo": {
        "startDateTime": "'+ $startDateTime + '",
        "expiration": {
            "type": "'+ $exptype + '",
            "duration": "'+ $duration + '"
        }
    }
}

'
        $endpoint = "/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"
        write-verbose "patch body : $body"
        $null = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
    }
    catch {
        MyCatch $_
    }

}
