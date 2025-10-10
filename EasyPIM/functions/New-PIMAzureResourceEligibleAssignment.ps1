<#
    .Synopsis
    Create an eligible assignement at the provided scope
    .Description
    Eligible assignment require users to activate their role before using it. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
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
    PS> New-PIMAzureResourceEligibleAssigment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Create an eligible assignment fot the role Arcpush, starting at a specific date and using default duration

    PS> New-PIMAzureResourceEligibleAssigment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "webmaster" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092 -justification 'TEST' -permanent

    Create a permanent eligible assignement for the role webmaster

        PS> New-PIMAzureResourceEligibleAssignment -tenantID $tenantID -scope "/subscriptions/$subscriptionId/resourceGroups/demo-rg" -rolename "Reader" -principalName "app@contoso.com"

        Resolve the principal name to its object ID before creating the eligible assignment.


    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMAzureResourceEligibleAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Position = 1)]
        [String]
        # subscription ID
        $subscriptionID,

        [Parameter()]
        [String]
        # scope if not at the subscription level
        $scope,

        [Parameter(Mandatory = $true)]
        [String]
        # Principal ID
        $principalID,

        [Parameter(Mandatory = $true)]
        [string]
        # the rolename for which we want to create an assigment
        $rolename,
            .Parameter principalID
            objectID of the principal (user, group or service principal)
            .Parameter principalName
            Display name, UPN, object ID, or appId of the principal. Will be resolved to principalID when provided.
        # duration of the assignment, if not set we will use the maximum allowed value from the role policy
        $duration,
            [CmdletBinding(DefaultParameterSetName = 'ByPrincipalId')]
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
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            if (!($PSBoundParameters.Keys.Contains('subscriptionID'))) {
                throw "ERROR : You must provide a subsciption ID or a scope, exiting."
            }
            $scope = "/subscriptions/$subscriptionID"
        }
        $script:tenantID = $tenantID

        $ARMhost = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
        $ARMendpoint = "$($ARMhost.TrimEnd('/'))/$scope/providers/Microsoft.Authorization"
        #1 get role id
        $restUri = "$ARMendpoint/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$rolename'"
        $response = Invoke-ARM -restURI $restUri -method "get" -body $null
        $roleID = $response.value.id
        write-verbose "Getting role ID for $rolename at $restURI"
        write-verbose "role ID = $roleid"



        if ($PSBoundParameters.Keys.Contains('startDateTime')) {
            $startDateTime = get-date ([datetime]::Parse($startDateTime)).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ"
        }
        else {
            $startDateTime = get-date (get-date).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ" #we get the date as UTC (remember to add a Z at the end or it will be translated to US timezone on import)
        }
        write-verbose "Calculated date time start is $startDateTime"

        # get role settings:
        $config = Get-PIMAzureResourcePolicy -tenantID $tenantID -scope $scope -rolename $rolename

        # if permanent assignement is requested check this is allowed in the rule
        if ($permanent) {
            if ( $config.AllowPermanentEligibleAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent eligible assignement, exiting"
            }
        }

        # Duration handling with normalization & policy validation
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $config.MaximumEligibleAssignmentDuration
        } else {
            $normalized = Convert-IsoDuration -Duration $duration
            $duration = $normalized
            try { $reqTs = [System.Xml.XmlConvert]::ToTimeSpan($duration) } catch { throw "Duration '$duration' cannot be parsed: $($_.Exception.Message)" }
            $policyTs = $null; if($config.MaximumEligibleAssignmentDuration){ try{ $policyTs=[System.Xml.XmlConvert]::ToTimeSpan($config.MaximumEligibleAssignmentDuration) } catch { Write-Verbose "Suppressed MaximumEligibleAssignmentDuration parse: $($_.Exception.Message)" } }
            if($policyTs -and $reqTs -gt $policyTs -and -not $permanent){ throw "Requested eligible assignment duration '$duration' exceeds policy maximum '$($config.MaximumEligibleAssignmentDuration)' for role $rolename." }
        }
    if($duration -and $duration -match '^P[0-9]+[HMS]$'){ $duration = Convert-IsoDuration -Duration $duration }
        write-verbose "assignement duration will be : $duration"

        if (!($PSBoundParameters.Keys.Contains('justification'))) {
            $justification = "Approved from EasyPIM module by  $($(get-azcontext).account)"
        }

        $type = "AfterDuration"
        if ($permanent) {
            $type = "NoExpiration"
        }

        $body = '
{
    "properties": {
        "principalId": "'+ $principalID + '",
        "roleDefinitionId": "'+ $roleID + '",
        "requestType": "AdminAssign",
        "justification": "'+ $justification + '",
        "scheduleInfo": {
            "startDateTime": "'+ $startDateTime + '",
            "expiration": {
                "type": "'+ $type + '",
                "endDateTime": null,
                "duration": "'+ $duration + '"
            }
        }
}
'
        $guid = New-Guid
        $restURI = "$armendpoint/roleEligibilityScheduleRequests/$($guid)?api-version=2020-10-01"
        write-verbose "sending PUT request at $restUri with body :`n $body"

        $response = Invoke-ARM -restURI $restUri -method PUT -body $body -Verbose:$false
        Write-Host "SUCCESS : Assignment created!"
        return $response
    }
    catch {
        Mycatch $_
    }
}
