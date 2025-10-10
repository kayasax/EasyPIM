<#
    .Synopsis
    Create an active assignement for the role $rolename and for the principal $principalID
    .Description
    Active assignment does not require users to activate their role. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
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
    PS> New-PIMEntraRoleActiveAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Create an active assignment fot the role Arcpush, starting at a specific date and using default duration

    PS> New-PIMEntraRoleActiveAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "webmaster" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092 -justification 'TEST' -permanent

    Create a permanent active assignement for the role webmaster

    PS> New-PIMEntraRoleActiveAssignment -tenantID $tenantID -rolename "Global Administrator" -principalName "user@contoso.com" -duration "PT1H"

    Resolve the UPN to its object ID and create a one-hour active assignment.

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMEntraRoleActiveAssignment {
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
        [switch]
        # the assignment will not expire
        $permanent,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [switch]
        # skip validation that group principals must be role-assignable (original check was removed; reintroduced as optional guard for clearer errors)
        $SkipGroupRoleAssignableCheck,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [switch]
        # emit full request body to verbose for troubleshooting (avoid in normal runs)
        $DebugGraphPayload
    )

    try {
        $script:tenantID = $tenantID

        if ($PSCmdlet.ParameterSetName -eq 'ByPrincipalName') {
            $resolvedPrincipal = Resolve-EasyPIMPrincipal -PrincipalIdentifier $principalName -AllowDisplayNameLookup -AllowAppIdLookup -ErrorContext 'New-PIMEntraRoleActiveAssignment'
            $principalID = $resolvedPrincipal.Id
            Write-Verbose "Resolved principalName '$principalName' to object ID '$principalID' (type=$($resolvedPrincipal.Type))."
        }

        # 1. Resolve principal object (groups no longer blocked if not role-assignable)
    $principalIdLen = if ([string]::IsNullOrEmpty($principalID)) { 0 } else { $principalID.Length }
        Write-Verbose "[ActiveAssign] principalID parameter raw='$principalID' length=$principalIdLen"
        $endpoint = "directoryObjects/$principalID"
        $response = invoke-graph -Endpoint $endpoint

        # If principal is a group, sanity check isAssignableToRole unless user opts out
        if (-not $SkipGroupRoleAssignableCheck) {
            $isGroup = $false
            try {
                if ($response.'@odata.type' -and $response.'@odata.type' -match 'group') {
                    $isGroup = $true
                }
            } catch {
                Write-Verbose "Suppressed principal type detection: $($_.Exception.Message)"
            }

            if ($isGroup) {
                Write-Verbose "Performing role-assignable check for group principalID='$principalID'"
                $g = $null; $groupFetchError = $null
                # Explicit interpolation to avoid accidental empty/omitted ID
                $grpEndpoint = "groups/$($principalID)?`$select=id,displayName,isAssignableToRole"
                Write-Verbose "Group fetch endpoint = $grpEndpoint"

                try {
                    $g = invoke-graph -Endpoint $grpEndpoint -Method GET -ErrorAction Stop
                } catch {
                    $groupFetchError = $_
                }

                if ($groupFetchError) {
                    Write-Verbose "Could not fetch group for role-assignable validation (continuing without enforcement): $($groupFetchError.Exception.Message)"
                } else {
                    # Determine presence of property without triggering analyzer false positive on null comparison
                    $hasProp = [bool]($g.PSObject.Properties.Name -contains 'isAssignableToRole')
                    if (-not $hasProp) {
                        Write-Verbose "isAssignableToRole missing in v1.0 response – retrying with beta endpoint for confirmation"
                        try {
                            $gBeta = invoke-graph -Endpoint $grpEndpoint -Method GET -version beta -ErrorAction Stop
                        } catch {
                            $gBeta = $null
                        }
                        if ($gBeta -and $gBeta.PSObject.Properties['isAssignableToRole']) {
                            $g = $gBeta; $hasProp = $true;
                            Write-Verbose "Beta endpoint returned isAssignableToRole=$($g.isAssignableToRole)"
                        }
                    }
                    if ($hasProp) {
                        if ($g.isAssignableToRole -is [bool]) {
                            if (-not $g.isAssignableToRole) {
                                throw "Group '$($g.displayName)' ($principalID) has isAssignableToRole=false and cannot receive directory role active assignments. Create a new role-assignable group (isAssignableToRole=true) or bypass with -SkipGroupRoleAssignableCheck (request likely to 400)."
                            } else {
                                Write-Verbose "Group $($g.displayName) confirmed role-assignable (isAssignableToRole=true)."
                            }
                        } else {
                            Write-Verbose "isAssignableToRole present but not boolean (value='$($g.isAssignableToRole)') — treating as inconclusive."
                        }
                    } else {
                        # Downgrade previous warning to verbose to reduce noise; true false absence usually means non-security group or insufficient permissions
                        Write-Verbose "Role-assignable status not returned (property absent after beta retry). Assuming allowed; specify -SkipGroupRoleAssignableCheck to skip this probe entirely."
                    }
                }
            }
        }

        # 2. Parse start date time
        if ($PSBoundParameters.Keys.Contains('startDateTime')) {
            $startDateTime = get-date ([datetime]::Parse($startDateTime)).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ"
        } else {
            $startDateTime = get-date (get-date).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ" #we get the date as UTC (remember to add a Z at the end or it will be translated to US timezone on import)
        }
        write-verbose "Calculated date time start is $startDateTime"

        # 3. Get role settings
        $config = Get-PIMEntraRolePolicy -tenantID $tenantID -rolename $rolename
        if ($config) {
            Write-Verbose ("Policy snapshot: ActiveReq='{0}' EnablementRules='{1}' AllowPermActive={2} MaxActive={3} ActivationDuration={4}" -f $config.ActiveAssignmentRequirement, $config.EnablementRules, $config.AllowPermanentActiveAssignment, $config.MaximumActiveAssignmentDuration, $config.ActivationDuration)
        }

        # 4. Check if permanent assignment is allowed
        if ($permanent) {
            if ( $config.AllowPermanentActiveAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent active assignement, exiting"
            }
        }

        # 5. Determine applicable policy maxima
        $policyMaxActive = $config.MaximumActiveAssignmentDuration
        $policyActivationMax = $config.ActivationDuration  # end-user activation (may also be enforced)

        # Check for problematic PT0S configuration that causes ExpirationRule failures
        if ($policyMaxActive -eq "PT0S") {
            Write-Warning "⚠️  POLICY ISSUE: MaximumActiveAssignmentDuration is set to PT0S (zero duration)."
            Write-Warning "   This will cause ExpirationRule validation failures for ANY duration request."
            Write-Warning "   Please update the role policy in Azure portal to set a reasonable maximum (e.g., P365D)."
            Write-Warning "   Path: Azure Portal > Microsoft Entra ID > Privileged Identity Management > Roles > $rolename > Role settings"
        }

        # For active assignments, use ActivationDuration as the primary limit since MaximumActiveAssignmentDuration may be PT0S (disabled)
        $effectiveLimit = $policyActivationMax
        if (!$effectiveLimit -and $policyMaxActive -and $policyMaxActive -ne "PT0S") {
            $effectiveLimit = $policyMaxActive
        }

        # 6. Determine duration
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            # Default to a conservative 30 minutes to avoid ExpirationRule policy violations
            $duration = if ($effectiveLimit) { $effectiveLimit } else { "PT30M" }
        } else {
            # Normalize duration BEFORE validation (P1H -> PT1H for Graph compliance)
            if ($duration -match '^P[0-9]+[HMS]$') {
                $normalized = ($duration -replace '^P','PT')
                Write-Verbose "Normalizing duration '$duration' -> '$normalized' for Graph compliance"
                $duration = $normalized
            }

            # user specified a duration: validate against the effective limit
            $reqIso = $duration
            $reqTs = ConvertFrom-ISO8601Duration $reqIso
            $effectiveLimitTs = ConvertFrom-ISO8601Duration $effectiveLimit
            if ($reqTs -and $effectiveLimitTs -and $reqTs -gt $effectiveLimitTs -and -not $permanent) {
                $humanReq = Format-TimeSpanHuman $reqTs
                $humanMax = Format-TimeSpanHuman $effectiveLimitTs
                throw "Requested active assignment duration '$reqIso' ($humanReq) exceeds policy limit '$effectiveLimit' ($humanMax) for role $rolename. Remove -Duration to use the maximum or choose a smaller value."
            }
        }

        Write-Verbose ("Duration selection: effective limit='{0}' (from ActivationDuration='{1}', fallback MaxActive='{2}') => using='{3}'" -f $effectiveLimit, $policyActivationMax, $policyMaxActive, $duration)
        Write-Verbose "assignement duration will be : $duration"

        # 7. Set justification
        if (!($PSBoundParameters.Keys.Contains('justification'))) {
            $justification = "Approved from EasyPIM module by  $($(get-azcontext).account)"
        }

        # 8. Build request body using PowerShell objects for reliable JSON formatting
        $requestBody = @{
            action = "adminAssign"
            justification = $justification
            roleDefinitionId = $config.roleID
            directoryScopeId = "/"
            principalId = $principalID
            scheduleInfo = @{
                startDateTime = $startDateTime
            }
        }

        # Add expiration info based on assignment type
        if ($permanent) {
            $requestBody.scheduleInfo.expiration = @{
                type = "NoExpiration"
            }
        } else {
            $requestBody.scheduleInfo.expiration = @{
                type = "AfterDuration"
                duration = $duration
            }
        }

        # Add ticketInfo only if required by policy
        if ($config.ActiveAssignmentRequirement -and $config.ActiveAssignmentRequirement -match "Ticketing") {
            Write-Verbose "TicketingRule detected - adding ticketInfo to request"
            $mgContext = Get-MgContext
            # PowerShell 5.x compatible null handling
            $authIdentifier = if ($mgContext.Account) {
                $mgContext.Account
            } elseif ($mgContext.ClientId) {
                $mgContext.ClientId
            } else {
                "Service Principal"
            }
            $requestBody.ticketInfo = @{
                ticketNumber = "EasyPIM-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                ticketSystem = "EasyPIM"
                ticketSubmitterIdentityId = $authIdentifier
                ticketApproverIdentityId = $authIdentifier
            }
        } else {
            Write-Verbose "No TicketingRule requirement detected - omitting ticketInfo"
        }

        # Convert to properly formatted JSON
        $body = $requestBody | ConvertTo-Json -Depth 10 -Compress

        # Allow environment variable to force full Graph error capture without passing switch everywhere
        if ($env:EASYPIM_DEBUG -eq '1') {
            $script:EasyPIM_FullGraphError = $true;
            Write-Verbose "EASYPIM_DEBUG=1 -> enabling full Graph error body capture"
        }
        if ($DebugGraphPayload) {
            Write-Verbose "Graph request body:`n$body"
            # enable full error body capture downstream
            $script:EasyPIM_FullGraphError = $true
        }

        # 9. Submit the request
        $endpoint = "roleManagement/directory/roleAssignmentScheduleRequests/"
        $result = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
        Write-Host "✅ Active assignment created successfully" -ForegroundColor Green
        return $result

    }
    catch {
        # Enhanced error handling for common PIM policy violations
        if ($_.Exception.Message -match "ExpirationRule") {
            Write-Error "ExpirationRule validation failed. This may be due to duration exceeding policy limits or invalid policy configuration. Check role settings with Get-PIMEntraRolePolicy. Error: $($_.Exception.Message)"
        } elseif ($_.Exception.Message -match "TicketingRule") {
            Write-Error "TicketingRule validation failed. The role requires valid ticket information for administrator assignments. Error: $($_.Exception.Message)"
        } else {
            Write-Error "Error in New-PIMEntraRoleActiveAssignment: $($_.Exception.Message)"
        }
        throw $_
    }
}
