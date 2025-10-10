<#
    .Synopsis
    Remove an active assignement for $rolename and for the principal $principalID
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
    .Parameter principalName
    Display name, user principal name (UPN), or object ID of the principal. Will be resolved to the principal ID if provided.
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
    PS> Remove-PIMEntraRoleActiveAssignment -tenantID $tenantID -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Remove the active assignment for the role Arcpush and principal $principalID, at a specific date

    PS> Remove-PIMEntraRoleActiveAssignment -tenantID $tenantID -rolename "webmaster" -principalname "user@contoso.com" -justification 'TEST'

    Resolve the provided principal name to its object ID and remove the active assignment for the role "webmaster".

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function Remove-PIMEntraRoleActiveAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding(DefaultParameterSetName = 'ByPrincipalId')]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [String]
        # Principal ID
        $principalID,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Principal name (display name, UPN, or object ID)
        $principalName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [string]
        # the rolename for which we want to create an assigment
        $rolename,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [string]
        # stat date of assignment if not provided we will use curent time
        $startDateTime,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [string]
        # justification (will be auto generated if not provided)
        $justification

    )

    try {
        $script:tenantID = $tenantID

        if ($PSCmdlet.ParameterSetName -eq 'ByPrincipalName') {
            Write-Verbose "Resolving principalName '$principalName'..."
            $resolvedPrincipal = $null

            try {
                $resolvedPrincipal = Resolve-EasyPIMPrincipal -PrincipalIdentifier $principalName -AllowDisplayNameLookup -AllowAppIdLookup -ErrorContext 'Remove-PIMEntraRoleActiveAssignment'
            }
            catch {
                Write-Verbose "Primary principal resolution failed for '$principalName': $($_.Exception.Message)"
            }

            if (-not $resolvedPrincipal) {
                Write-Verbose "Falling back to active assignment lookup for '$principalName'."
                $matchingAssignments = Get-PIMEntraRoleActiveAssignment -tenantID $tenantID -rolename $rolename -principalName $principalName
                $principalCandidates = $matchingAssignments | Select-Object -ExpandProperty principalid -Unique

                if (-not $principalCandidates -or $principalCandidates.Count -eq 0) {
                    throw "No active assignment found matching principalName '$principalName' for role '$rolename'. Provide -principalID or ensure the name matches an active assignment."
                }

                if ($principalCandidates.Count -gt 1) {
                    throw "Multiple active assignments matched principalName '$principalName' for role '$rolename'. Provide -principalID or refine the name to a unique match."
                }

                $principalID = $principalCandidates[0]
                Write-Verbose "Resolved principalName '$principalName' via active assignments to object ID '$principalID'."
            }
            else {
                $principalID = $resolvedPrincipal.Id
                Write-Verbose "Resolved principalName '$principalName' to object ID '$principalID' (type=$($resolvedPrincipal.Type))."
            }
        }


        if ($PSBoundParameters.Keys.Contains('startDateTime')) {
            $startDateTime = get-date ([datetime]::Parse($startDateTime)).touniversaltime().addseconds(30) -f "yyyy-MM-ddTHH:mm:ssZ"
        }
        else {
            $startDateTime = get-date (get-date).touniversaltime().addseconds(30) -f "yyyy-MM-ddTHH:mm:ssZ" #we get the date as UTC (remember to add a Z at the end or it will be translated to US timezone on import)
        }

        write-verbose "Calculated date time start is $startDateTime"
        # 2 get role settings:
        $config = Get-PIMEntraRolePolicy -tenantID $tenantID -rolename $rolename

        #if permanent assignement is requested check this is allowed in the rule
        if ($permanent) {
            if ( $config.AllowPermanentEligibleAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent eligible assignement, exiting"
            }
        }

        # if Duration is not provided we will take the maxium value from the role setting
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $config.MaximumEligibleAssignmentDuration
        }
        write-verbose "assignement duration will be : $duration"

        if (!($PSBoundParameters.Keys.Contains('justification'))) {
            $justification = "Approved from EasyPIM module by  $($(get-azcontext).account)"
        }


        $type = "AfterDuration"
        #$type="afterDateTime"
        if ($permanent) {
            $type = "NoExpiration"
        }

        $body = '
{
    "action": "adminRemove",
    "justification": "'+ $justification + '",
    "roleDefinitionId": "'+ $config.roleID + '",
    "directoryScopeId": "/",
    "principalId": "'+ $principalID + '",
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
        $endpoint = "/roleManagement/directory/roleAssignmentScheduleRequests"
        write-verbose "patch body : $body"
        $null = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
        Write-Host "SUCCESS : Assignment removed!"
    }
    catch { Mycatch $_ }
}
