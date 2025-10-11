<#
    .Synopsis
    Remove an eligible assignment for the specified Entra role.
    .Description
    Eligible assignments grant principals the ability to activate a role when needed. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
    .Parameter subscriptionID
    subscription ID
    .Parameter Scope
    Optional directory scope for the removal request. Provide '/' for tenant scope (default), an Administrative Unit GUID, display name, or a full path like '/administrativeUnits/<GUID>'.
    .Parameter principalID
    objectID of the principal (user, group or service principal)
    .Parameter principalName
    Display name, UPN, object ID, or appId of the principal. Will be resolved to principalID when provided.
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
    PS> Remove-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092

    Remove the eligible assignment for the role AcrPush and the specified principal ID.

    PS> Remove-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "Global Administrator" -principalName "user@contoso.com"

    Resolve the principal name to its object ID and remove the eligible assignment for Global Administrator.

    PS> Remove-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "Helpdesk Administrator" -principalId $principal.Id -Scope "e2a1d1b3-3a8a-4cc8-9ff6-8a90e2f17c11"

    Remove the eligible assignment scoped to a specific Administrative Unit by supplying its GUID (translated to '/administrativeUnits/<GUID>').

    PS> Remove-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "Helpdesk Administrator" -principalId $principal.Id -Scope "Sales Operations AU"

    Remove the eligible assignment scoped to a specific Administrative Unit by referencing the AU display name; the name is resolved to its GUID automatically.

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function Remove-PIMEntraRoleEligibleAssignment {
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
        # Principal name or identifier
        $principalName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [string]
        # the rolename for which we want to create an assigment
        $rolename,

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
        [Alias('DirectoryScopeId','AdministrativeUnitId')]
        [string]
        # Optional scope for the removal request; defaults to '/' (tenant)
        $Scope,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [switch]
        # the assignment will not expire
        $permanent

    )

    try {
        $script:tenantID = $tenantID

        if ($PSCmdlet.ParameterSetName -eq 'ByPrincipalName') {
            $resolvedPrincipal = $null
            try {
                $resolvedPrincipal = Resolve-EasyPIMPrincipal -PrincipalIdentifier $principalName -AllowDisplayNameLookup -AllowAppIdLookup -ErrorContext 'Remove-PIMEntraRoleEligibleAssignment'
            }
            catch {
                Write-Verbose "Primary principal resolution failed for '$principalName': $($_.Exception.Message)"
            }

            if ($resolvedPrincipal) {
                $principalID = $resolvedPrincipal.Id
                Write-Verbose "Resolved principalName '$principalName' to object ID '$principalID' (type=$($resolvedPrincipal.Type))."
            }
            else {
                Write-Verbose "Falling back to eligible assignment lookup for '$principalName'."
                $matchingAssignments = Get-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename $rolename -principalName $principalName
                $principalCandidates = $matchingAssignments | Select-Object -ExpandProperty principalid -Unique

                if (-not $principalCandidates -or $principalCandidates.Count -eq 0) {
                    throw "No eligible assignment found matching principalName '$principalName' for role '$rolename'. Provide -principalID or ensure the name matches an eligible assignment."
                }

                if ($principalCandidates.Count -gt 1) {
                    throw "Multiple eligible assignments matched principalName '$principalName' for role '$rolename'. Provide -principalID or refine the name to a unique match."
                }

                $principalID = $principalCandidates[0]
                Write-Verbose "Resolved principalName '$principalName' via eligible assignment lookup to object ID '$principalID'."
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

        # Resolve the directory scope to the correct Graph identifier (defaults to '/' for tenant scope)
        $targetScope = Resolve-EasyPIMDirectoryScope -Scope $Scope -DefaultScope '/' -ErrorContext 'Remove-PIMEntraRoleEligibleAssignment'

        $body = '
{
    "action": "adminRemove",
    "justification": "'+ $justification + '",
    "roleDefinitionId": "'+ $config.roleID + '",
    "directoryScopeId": "'+ $targetScope + '",
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
        $endpoint = "/roleManagement/directory/roleEligibilityScheduleRequests"
        write-verbose "patch body : $body"
        $null = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
        Write-Host "SUCCESS : Assignment removed!"
    }
    catch { Mycatch $_ }
}
