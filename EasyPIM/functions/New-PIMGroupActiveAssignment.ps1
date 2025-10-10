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
    .Parameter principalName
    Display name, UPN, object ID, or appId of the principal. Will be resolved to principalID when provided.
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

    PS> New-PIMGroupActiveAssignment -tenantID $tenantID -groupID $gID -principalName "user@contoso.com" -type member -duration "P14D"

    Create an active assignment resolved from principal name for the membership role of the group $gID lasting 14 days
    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMGroupActiveAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByPrincipalId')]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Group ID
        $groupID,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [String]
        # Principal ID
        $principalID,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Principal name or identifier
        $principalName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [string]
        # the rolename for which we want to create an assigment
        $type,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [string]
        # duration of the assignment, if not set we will use the maximum allowed value from the role policy
        $duration,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [string]
        # stat date of assignment if not provided we will use curent time
        $startDateTime,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [string]
        # justification (will be auto generated if not provided)
        $justification,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [switch]
        # the assignment will not expire
        $permanent

    )

    try {
        $script:tenantID = $tenantID

        if ($PSCmdlet.ParameterSetName -eq 'ByPrincipalName') {
            $resolvedPrincipal = Resolve-EasyPIMPrincipal -PrincipalIdentifier $principalName -AllowDisplayNameLookup -AllowAppIdLookup -ErrorContext 'New-PIMGroupActiveAssignment'
            $principalID = $resolvedPrincipal.Id
            Write-Verbose "Resolved principalName '$principalName' to object ID '$principalID' (type=$($resolvedPrincipal.Type))."
        }

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
            if ($config.AllowPermanentActiveAssignment -eq "false") {
                throw "ERROR : The group role $type does not allow permanent eligible assignement, exiting"
            }
        }

        # Duration handling with normalization & policy validation
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $config.MaximumActiveAssignmentDuration
        } else {
            $normalized = Convert-IsoDuration -Duration $duration
            $duration = $normalized
            try { $reqTs = [System.Xml.XmlConvert]::ToTimeSpan($duration) } catch { throw "Duration '$duration' cannot be parsed: $($_.Exception.Message)" }
            $policyTs = $null; if($config.MaximumActiveAssignmentDuration){ try{ $policyTs=[System.Xml.XmlConvert]::ToTimeSpan($config.MaximumActiveAssignmentDuration) } catch { Write-Verbose "Suppressed MaximumActiveAssignmentDuration parse: $($_.Exception.Message)" } }
            if($policyTs -and $reqTs -gt $policyTs -and -not $permanent){ throw "Requested active assignment duration '$duration' exceeds policy maximum '$($config.MaximumActiveAssignmentDuration)' for group role $type." }
        }
    if($duration -and $duration -match '^P[0-9]+[HMS]$'){ $duration = Convert-IsoDuration -Duration $duration }
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

        if ($PSCmdlet.ShouldProcess("Group $groupID", "Create PIM Active Assignment")) {
            $response = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
            return $response
        }
    }
    catch {
        MyCatch $_
    }

}
