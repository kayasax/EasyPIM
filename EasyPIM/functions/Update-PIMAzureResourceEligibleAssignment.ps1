<#
    .Synopsis
    Extend (AdminExtend) an existing, still-valid eligible Azure resource role assignment that is about to expire.
    .Description
    Submits an ARM roleEligibilityScheduleRequests request with requestType 'AdminExtend', pushing the assignment's
    end date out to -newEndDateTime. Admin-initiated extension requires no approval; it only notifies other admins.
    Use this to renew time-bound eligibility before it lapses (as opposed to AdminRenew, which reactivates an
    already-expired assignment). The target schedule is resolved from the principal's existing eligible schedules.
    .Parameter tenantID
    EntraID tenant ID
    .Parameter subscriptionID
    Subscription ID (used to build the scope when -scope is not supplied)
    .Parameter scope
    Use scope if you want to target a scope other than the subscription
    .Parameter principalID
    ObjectID of the principal (user, group or service principal) whose assignment is extended
    .Parameter rolename
    Name of the role whose eligible assignment is extended
    .Parameter newEndDateTime
    The new expiration date/time for the assignment. Parsed and sent as UTC.
    .Parameter justification
    Justification (auto-generated if not provided)
    .Example
    PS> Update-PIMAzureResourceEligibleAssignment -tenantID $t -subscriptionID $s -rolename "Reader" -principalID $p -newEndDateTime "2026-12-31"

    Extend the Reader eligible assignment for the principal to the end of 2026.
    .Link
    https://learn.microsoft.com/azure/templates/microsoft.authorization/roleeligibilityschedulerequests
    .Notes
    Author: EasyPIM contributors
    Homepage: https://github.com/kayasax/EasyPIM
#>
function Update-PIMAzureResourceEligibleAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true)][String]$tenantID,
        [Parameter()][String]$subscriptionID,
        [Parameter()][String]$scope,
        [Parameter(Mandatory = $true)][String]$principalID,
        [Parameter(Mandatory = $true)][String]$rolename,
        [Parameter(Mandatory = $true)][String]$newEndDateTime,
        [Parameter()][String]$justification
    )

    try {
        if (-not $PSBoundParameters.Keys.Contains('scope')) {
            if (-not $PSBoundParameters.Keys.Contains('subscriptionID')) {
                throw "ERROR : You must provide a subscription ID or a scope, exiting."
            }
            $scope = "/subscriptions/$subscriptionID"
        }
        $script:tenantID = $tenantID

        $ARMhost = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
        $ARMendpoint = "$($ARMhost.TrimEnd('/'))/$($scope.TrimStart('/'))/providers/Microsoft.Authorization"

        # 1. Resolve role definition id
        $restUri = "$ARMendpoint/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$rolename'"
        $roleResponse = Invoke-ARM -restURI $restUri -method "get" -body $null
        $roleID = ($roleResponse.value | Select-Object -First 1).id
        if (-not $roleID) { throw "ERROR : Role '$rolename' not found at scope $scope." }
        Write-Verbose "Resolved role '$rolename' to $roleID"

        # 2. Normalize new end date to UTC ISO 8601 with trailing Z
        $newEnd = Get-Date ([datetime]::Parse($newEndDateTime)).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ"
        Write-Verbose "New end date (UTC): $newEnd"

        # 3. Find the target eligibility schedule id for this principal + role + scope
        $schedUri = "$ARMendpoint/roleEligibilitySchedules?api-version=2020-10-01-preview&`$filter=assignedTo('$principalID')"
        $schedResponse = Invoke-ARM -restURI $schedUri -method "get" -body $null
        $targetSchedule = $schedResponse.value | Where-Object {
            $_.properties.roleDefinitionId -eq $roleID -and $_.properties.scope -eq $scope
        } | Select-Object -First 1
        if (-not $targetSchedule) {
            throw "ERROR : No eligible assignment found for principal $principalID role '$rolename' at scope $scope to extend."
        }
        $targetScheduleId = $targetSchedule.id
        Write-Verbose "Target eligibility schedule id: $targetScheduleId"

        # 4. Idempotency: skip if an AdminExtend request for this schedule is already in flight
        $reqListUri = "$ARMendpoint/roleEligibilityScheduleRequests?api-version=2020-10-01&`$filter=principalId eq '$principalID'"
        $reqList = Invoke-ARM -restURI $reqListUri -method "get" -body $null
        $inFlight = $reqList.value | Where-Object {
            $_.properties.targetRoleEligibilityScheduleId -eq $targetScheduleId -and
            $_.properties.requestType -eq 'AdminExtend' -and
            $_.properties.status -match 'Pending|Accepted|Granted'
        }
        if ($inFlight) {
            Write-Warning "An AdminExtend request is already pending for role '$rolename' principal $principalID at scope $scope. Skipping."
            return
        }

        if (-not $PSBoundParameters.Keys.Contains('justification')) {
            $justification = "Extended by EasyPIM by $($(Get-AzContext).account)"
        }

        # 5. Build and submit the AdminExtend request
        $body = @"
{
    "properties": {
        "principalId": "$principalID",
        "roleDefinitionId": "$roleID",
        "requestType": "AdminExtend",
        "justification": "$justification",
        "targetRoleEligibilityScheduleId": "$targetScheduleId",
        "scheduleInfo": {
            "expiration": {
                "type": "AfterDateTime",
                "endDateTime": "$newEnd"
            }
        }
    }
}
"@

        $guid = New-Guid
        $putUri = "$ARMendpoint/roleEligibilityScheduleRequests/$($guid)?api-version=2020-10-01"

        if ($PSCmdlet.ShouldProcess("$rolename / $principalID @ $scope", "Extend eligible assignment to $newEnd")) {
            Write-Verbose "Sending AdminExtend PUT at $putUri with body:`n$body"
            $response = Invoke-ARM -restURI $putUri -method PUT -body $body -Verbose:$false
            Write-Host "SUCCESS : Eligible assignment extended to $newEnd"
            return $response
        }
    }
    catch {
        Mycatch $_
    }
}
