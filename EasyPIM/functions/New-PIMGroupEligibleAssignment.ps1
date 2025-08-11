<#
    .Synopsis
    Create an active assignement at the provided scope
    .Description
    Active assignment does not require users to activate their role. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
    .Parameter subscriptionID
    subscription ID
    .Parameter scope
    use scope parameter if you want to work at other scope than a subscription
    .Parameter principalID
    objectID of the principal (user, group or service principal)
    .Parameter rolename
    name of the role to assign
    .Parameter duration
    duration of the assignment, if not set we will use the maximum allowed value from the role policy
    .Parameter startDateTime
    When the assignment wil begin, if not set we will use current time
    .Parameter permanent
    Use this parameter if you want a permanent assignement (no expiration)
    .Parameter justification
    justification


    .Example
    PS> New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Create an active assignment fot the role Arcpush, starting at a specific date and using default duration

    PS> New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "webmaster" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092 -justification 'TEST' -permanent

    Create a permanent active assignement for the role webmaster

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMGroupEligibleAssignment {
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
            if ( $config.AllowPermanentEligibleAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent eligble assignement, exiting"
            }
        }

        # Duration handling with normalization & policy validation
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $config.MaximumEligibleAssignmentDuration
        } else {
            $normalized = Normalize-IsoDuration -Duration $duration
            $duration = $normalized
            try { $reqTs = [System.Xml.XmlConvert]::ToTimeSpan($duration) } catch { throw "Duration '$duration' cannot be parsed: $($_.Exception.Message)" }
            $policyTs = $null; if($config.MaximumEligibleAssignmentDuration){ try{ $policyTs=[System.Xml.XmlConvert]::ToTimeSpan($config.MaximumEligibleAssignmentDuration) } catch {} }
            if($policyTs -and $reqTs -gt $policyTs -and -not $permanent){ throw "Requested eligible assignment duration '$duration' exceeds policy maximum '$($config.MaximumEligibleAssignmentDuration)' for group role $type." }
        }
        if($duration -and $duration -match '^P[0-9]+[HMS]$'){ $duration = Normalize-IsoDuration -Duration $duration }
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
            "endDateTime": null,
            "duration": "'+ $duration + '"
        }
    }
}

'
        $endpoint = "/identityGovernance/privilegedAccess/group/EligibilityScheduleRequests"
        write-verbose "patch body : $body"
        $response = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
        Return $response
    }
    catch {
        MyCatch $_
    }

}
