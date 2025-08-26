<#
    .Synopsis
    Create an active assignement for the role $rolename and for the principal $principalID
    .Description
    Active assignment does not require users to activate their role. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
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
    PS> New-PIMEntraRoleActiveAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Create an active assignment fot the role Arcpush, starting at a specific date and using default duration

    PS> New-PIMEntraRoleActiveAssignment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "webmaster" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092 -justification 'TEST' -permanent

    Create a permanent active assignement for the role webmaster

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMEntraRoleActiveAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Mandatory = $true)]
        [String]
        # Principal ID
        $principalID,

        [Parameter(Mandatory = $true)]
        [string]
        # the rolename for which we want to create an assigment
        $rolename,

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
    $permanent,

    [switch]
    # skip validation that group principals must be role-assignable (original check was removed; reintroduced as optional guard for clearer errors)
    $SkipGroupRoleAssignableCheck,

    [switch]
    # emit full request body to verbose for troubleshooting (avoid in normal runs)
    $DebugGraphPayload

    )

    try {
        $script:tenantID = $tenantID

    #1 resolve principal object (groups no longer blocked if not role-assignable)
    $principalIdLen = if ([string]::IsNullOrEmpty($principalID)) { 0 } else { $principalID.Length }
    Write-Verbose "[ActiveAssign] principalID parameter raw='$principalID' length=$principalIdLen"
    $endpoint = "directoryObjects/$principalID"
    $response = invoke-graph -Endpoint $endpoint
        # If principal is a group, sanity check isAssignableToRole unless user opts out
        if (-not $SkipGroupRoleAssignableCheck) {
            $isGroup = $false
            try { if ($response.'@odata.type' -and $response.'@odata.type' -match 'group') { $isGroup = $true } } catch { Write-Verbose "Suppressed principal type detection: $($_.Exception.Message)" }
            if ($isGroup) {
                Write-Verbose "Performing role-assignable check for group principalID='$principalID'"
                $g = $null; $groupFetchError = $null
                # Explicit interpolation to avoid accidental empty/omitted ID
                $grpEndpoint = "groups/$($principalID)?`$select=id,displayName,isAssignableToRole"
                Write-Verbose "Group fetch endpoint = $grpEndpoint"
                try { $g = invoke-graph -Endpoint $grpEndpoint -Method GET -ErrorAction Stop } catch { $groupFetchError = $_ }
                if ($groupFetchError) {
                    Write-Verbose "Could not fetch group for role-assignable validation (continuing without enforcement): $($groupFetchError.Exception.Message)"
                } else {
                    # Determine presence of property without triggering analyzer false positive on null comparison
                    $hasProp = [bool]($g.PSObject.Properties.Name -contains 'isAssignableToRole')
                    if (-not $hasProp) {
                        Write-Verbose "isAssignableToRole missing in v1.0 response – retrying with beta endpoint for confirmation"
                        try { $gBeta = invoke-graph -Endpoint $grpEndpoint -Method GET -version beta -ErrorAction Stop } catch { $gBeta = $null }
                        if ($gBeta -and $gBeta.PSObject.Properties['isAssignableToRole']) { $g = $gBeta; $hasProp=$true; Write-Verbose "Beta endpoint returned isAssignableToRole=$($g.isAssignableToRole)" }
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
        # local helper to parse ISO 8601 durations like P30D, PT8H, PT2H30M etc.
        function ConvertFrom-ISO8601Duration([string]$iso) {
            if (-not $iso) { return $null }
            try { return [System.Xml.XmlConvert]::ToTimeSpan($iso) } catch { Write-Verbose "Suppressed ISO8601 duration parse failure: $($_.Exception.Message)" }
            return $null
        }
        function Format-TimeSpanHuman([TimeSpan]$ts) {
            if (-not $ts) { return '' }
            if ($ts.Days -ge 1 -and $ts.Hours -eq 0 -and $ts.Minutes -eq 0) { return "$($ts.Days)d" }
            if ($ts.Days -ge 1) { return "$($ts.Days)d $($ts.Hours)h" }
            if ($ts.TotalHours -ge 1 -and $ts.Minutes -eq 0) { return "$([int]$ts.TotalHours)h" }
            if ($ts.TotalHours -ge 1) { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
            if ($ts.Minutes -ge 1) { return "$($ts.Minutes)m" }
            return "$([math]::Round($ts.TotalSeconds))s"
        }
        if ($PSBoundParameters.Keys.Contains('startDateTime')) {
            $startDateTime = get-date ([datetime]::Parse($startDateTime)).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ"
        }
        else {
            $startDateTime = get-date (get-date).touniversaltime() -f "yyyy-MM-ddTHH:mm:ssZ" #we get the date as UTC (remember to add a Z at the end or it will be translated to US timezone on import)
        }
        write-verbose "Calculated date time start is $startDateTime"
        # 2 get role settings:
        $config = Get-PIMEntraRolePolicy -tenantID $tenantID -rolename $rolename
        if ($config) {
            Write-Verbose ("Policy snapshot: ActiveReq='{0}' EnablementRules='{1}' AllowPermActive={2} MaxActive={3} ActivationDuration={4}" -f $config.ActiveAssignmentRequirement,$config.EnablementRules,$config.AllowPermanentActiveAssignment,$config.MaximumActiveAssignmentDuration,$config.ActivationDuration)
        }

        #if permanent assignement is requested check this is allowed in the rule
        if ($permanent) {
            if ( $config.AllowPermanentActiveAssignment -eq "false") {
                throw "ERROR : The role $rolename does not allow permanent active assignement, exiting"
            }
        }

        # Determine applicable policy maxima
        $policyMaxActive = $config.MaximumActiveAssignmentDuration
        $policyActivationMax = $config.ActivationDuration  # end-user activation (may also be enforced)
        
        # For active assignments, use ActivationDuration as the primary limit since MaximumActiveAssignmentDuration may be PT0S (disabled)
        $effectiveLimit = $policyActivationMax
        if (!$effectiveLimit -and $policyMaxActive) { $effectiveLimit = $policyMaxActive }
        
        # if Duration is not provided we will take the effective limit
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $effectiveLimit
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
        Write-Verbose ("Duration selection: effective limit='{0}' (from ActivationDuration='{1}', fallback MaxActive='{2}') => using='{3}'" -f $effectiveLimit,$policyActivationMax,$policyMaxActive,$duration)
        # Additional normalization for any remaining non-standard forms 
        if ($duration -match '^P[0-9]+[HMS]$') {
            $normalized = ($duration -replace '^P','PT')
            Write-Verbose "Normalizing duration '$duration' -> '$normalized' for Graph compliance"
            $duration = $normalized
        }
        Write-Verbose "assignement duration will be : $duration"

        if (!($PSBoundParameters.Keys.Contains('justification'))) {
            $justification = "Approved from EasyPIM module by  $($(get-azcontext).account)"
        }

        $type = "AfterDuration"
        if ($permanent) {
            $type = "NoExpiration"
        }

        $body = '
{
    "action": "adminAssign",
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
    },
    "ticketInfo": {
        "ticketNumber": "EasyPIM",
        "ticketSystem": "EasyPIM"
    }
}

'
    # Allow environment variable to force full Graph error capture without passing switch everywhere
    if ($env:EASYPIM_DEBUG -eq '1') { $script:EasyPIM_FullGraphError = $true; Write-Verbose "EASYPIM_DEBUG=1 -> enabling full Graph error body capture" }
    if ($DebugGraphPayload) {
        Write-Verbose "Graph request body:`n$body"
        # enable full error body capture downstream
        $script:EasyPIM_FullGraphError = $true
    }
    $endpoint = "roleManagement/directory/roleAssignmentScheduleRequests/"
    invoke-graph -Endpoint $endpoint -Method "POST" -body $body

    }
    catch {
        MyCatch $_
    }
}
