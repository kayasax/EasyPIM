<#
    .Synopsis
    Create an eligible assignement for $rolename and for the principal $principalID
    .Description
    Eligible assignment require users to activate their role. https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
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
    PS> New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092  -startDateTime "2/2/2024 18:20"

    Create an active assignment fot the role Arcpush, starting at a specific date and using default duration

    PS> New-PIMEntraRoleEligibleAssignment -tenantID $tenantID -rolename "webmaster" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092 -justification 'TEST' -permanent

    Create a permanent active assignement for the role webmaster

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function New-PIMEntraRoleEligibleAssignment {
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
    # skip validation that group principals are role-assignable (mirrors active assignment cmdlet)
    $SkipGroupRoleAssignableCheck

    )

    try {
        $script:tenantID = $tenantID

    #1 resolve principal object (groups no longer blocked if not role-assignable)
    $endpoint = "directoryObjects/$principalID"
    $response = invoke-graph -Endpoint $endpoint
    if($response -and $response.'@odata.type') { Write-Verbose "[EligibleAssign] Resolved principal type: $($response.'@odata.type')" }
    if(-not $SkipGroupRoleAssignableCheck){
        $isGroup = $false
        try { if ($response.'@odata.type' -and $response.'@odata.type' -match 'group') { $isGroup = $true } } catch { Write-Verbose "Suppressed principal type detection: $($_.Exception.Message)" }
        if($isGroup){
            Write-Verbose "Performing role-assignable check (eligible) for group principalID='$principalID'"
            $g = $null; $groupFetchError = $null
            $grpEndpoint = "groups/$($principalID)?`$select=id,displayName,isAssignableToRole"
            Write-Verbose "Group fetch endpoint (eligible) = $grpEndpoint"
            try { $g = invoke-graph -Endpoint $grpEndpoint -Method GET -ErrorAction Stop } catch { $groupFetchError = $_ }
            if($groupFetchError){
                Write-Verbose "Could not fetch group for role-assignable validation (eligible): $($groupFetchError.Exception.Message)"
            } else {
                $hasProp = [bool]($g.PSObject.Properties.Name -contains 'isAssignableToRole')
                if(-not $hasProp){
                    Write-Verbose "isAssignableToRole missing in v1.0 response (eligible) – retrying with beta endpoint"
                    try { $gBeta = invoke-graph -Endpoint $grpEndpoint -Method GET -version beta -ErrorAction Stop } catch { $gBeta = $null }
                    if ($gBeta -and $gBeta.PSObject.Properties['isAssignableToRole']) { $g = $gBeta; $hasProp = $true; Write-Verbose "Beta endpoint (eligible) returned isAssignableToRole=$($g.isAssignableToRole)" }
                }
                if($hasProp){
                    if ($g.isAssignableToRole -is [bool]) {
                        if(-not $g.isAssignableToRole){
                            throw "Group '$($g.displayName)' ($principalID) has isAssignableToRole=false and cannot receive directory role eligible assignments. Create a role-assignable group (isAssignableToRole=true) or bypass with -SkipGroupRoleAssignableCheck (request likely to 400)."
                        } else { Write-Verbose "Group $($g.displayName) confirmed role-assignable (isAssignableToRole=true) for eligible." }
                    } else { Write-Verbose "isAssignableToRole present but not boolean (eligible) value='$($g.isAssignableToRole)'" }
                } else {
                    Write-Verbose "Role-assignable status not returned (eligible, property absent after beta retry). Assuming allowed; specify -SkipGroupRoleAssignableCheck to skip probe." }
            }
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

        # Duration handling with normalization & policy validation
        if (!($PSBoundParameters.Keys.Contains('duration'))) {
            $duration = $config.MaximumEligibleAssignmentDuration
        } else {
            $normalized = Convert-IsoDuration -Duration $duration
            $duration = $normalized
            $reqTs = [System.Xml.XmlConvert]::ToTimeSpan($duration)
            $policyTs = $null; if($config.MaximumEligibleAssignmentDuration){ try{ $policyTs=[System.Xml.XmlConvert]::ToTimeSpan($config.MaximumEligibleAssignmentDuration) } catch { Write-Verbose "Suppressed MaximumEligibleAssignmentDuration parse: $($_.Exception.Message)" } }
            if($policyTs -and $reqTs -gt $policyTs -and -not $permanent){
                throw "Requested eligible assignment duration '$duration' exceeds policy maximum '$($config.MaximumEligibleAssignmentDuration)' for role $rolename. Remove -Duration to use the maximum or choose a smaller value."
            }
        }
    if($duration -and $duration -match '^P[0-9]+[HMS]$'){ $duration = Convert-IsoDuration -Duration $duration }
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
    }
}

'
        $endpoint = "/roleManagement/directory/roleEligibilityScheduleRequests"
        write-verbose "patch body : $body"
        $null = invoke-graph -Endpoint $endpoint -Method "POST" -body $body
    }
    catch {
        MyCatch $_
    }

}
