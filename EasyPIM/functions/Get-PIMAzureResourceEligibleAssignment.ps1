<#
    .Synopsis
    List of eligible assignement defined at the provided scope or bellow
    .Description
     https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
    .Parameter subscriptionID
    subscription ID
    .Parameter scope
    use scope parameter if you want to work at other scope than a subscription    .PARAMETER principalId
    Filter assignment using userPrincipalName or objectID (alias: assignee for backward compatibility)
    .PARAMETER userPrincipalName
    Filter by userPrincipalName (UPN). Will resolve to object ID for efficient ARM API filtering.
    .Parameter summary
    When enabled will return the most useful information only
    .Parameter atBellowScope
    Will return only the assignment defined at lower scopes    .Example
    PS> Get-PIMAzureResourceEligibleAssignment -tenantID $tid -subscriptionID -subscription $subscription

    List active assignement at the subscription scope.

    .Example
    PS> Get-PIMAzureResourceEligibleAssignment -tenantID $tid -subscriptionID $sub -userPrincipalName "user@domain.com"

    List eligible assignments for a specific user by UPN


    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>

function Get-PIMAzureResourceEligibleAssignment {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        [Parameter(Position = 1)]
        [String]
        $subscriptionID,
        [Parameter()]
        [String]
        $scope,        [Alias('assignee')]
        [String]
        $principalId,
        [String]
        $userPrincipalName,
        [switch]
        # when enable we will use the roleEligibilitySchedules API which also list the future assignments
        $includeFutureAssignments,
        [switch]
        # select the most usefull info only
        $summary,
        [switch]
        # return only assignment defined at a lower scope
        $atBellowScope
    )

    try {        $script:tenantID = $tenantID

        # Resolve userPrincipalName to object ID if provided
        $resolvedPrincipalId = $null
        if ($PSBoundParameters.Keys.Contains('userPrincipalName')) {
            try {
                Write-Verbose "Resolving userPrincipalName '$userPrincipalName' to object ID..."
                $userEndpoint = "/users/$userPrincipalName"
                $userResponse = invoke-graph -Endpoint $userEndpoint
                $resolvedPrincipalId = $userResponse.id
                Write-Verbose "Resolved to object ID: $resolvedPrincipalId"
            }
            catch {
                Write-Warning "Could not resolve userPrincipalName '$userPrincipalName': $($_.Exception.Message)"
                # Return empty result if user not found
                Write-Output "0 eligible assignment(s) found for scope $scope"
                return @()
            }
        }

       # Validate that either scope or subscriptionID is provided
        if (!($PSBoundParameters.Keys.Contains('scope')) -and !($PSBoundParameters.Keys.Contains('subscriptionID'))) {
            throw "Either -scope or -subscriptionID parameter must be provided. Cannot determine which Azure resource scope to query."
        }

        # Set default scope if not explicitly provided
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            $scope = "/subscriptions/$subscriptionID"
        }

        # issue #23: due to a bug with the API regarding the membertype, we will use RoleEligibilitySchedulesInstance instead of RoleEligibilitySchedule
        # the downside is we will not get assignment with a future start date
        $armEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
        if ($PSBoundParameters.Keys.Contains('includeFutureAssignments')) {
            $restURI = "$($armEndpoint.TrimEnd('/'))/$scope/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01-preview"
        }
        else {
            $restURI = "$($armEndpoint.TrimEnd('/'))/$scope/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01-preview"
        }

        # Determine which principal ID to use for filtering
        $effectivePrincipalId = $null
        if ($resolvedPrincipalId) {
            $effectivePrincipalId = $resolvedPrincipalId
        }
        elseif ($PSBoundParameters.Keys.Contains('principalId')) {
            if($principalId -match ".+@.*\..+") { # if this is a UPN we will use graph to get the objectID
                try{
                    $resu=invoke-graph -endpoint "users/$principalId" -Method GET -version "beta"
                    $effectivePrincipalId = $resu.id
                }
                catch {
                    Write-Warning "User $principalId not found in the tenant"
                    return @()
                }
            }
            else {
                $effectivePrincipalId = $principalId
            }
        }

        # Add principal filtering to REST URI if we have a principal ID
        if ($effectivePrincipalId) {
            $restURI += "&`$filter=assignedto('"+$effectivePrincipalId+"')"
        }




        $response = Invoke-ARM -restURI $restURI -method get
        #$response|select -first 1

        $return = @()
        #$id=$response.value.id
        #$response.value.properties |get-member

        $response.value | ForEach-Object {
            $id = $_.id
            #echo "ID: $id"
            $_.properties | ForEach-Object {
                #$_
                if ($null -eq $_.endDateTime ) { $end = "permanent" }else { $end = $_.endDateTime }
                $properties = @{
                    "PrincipalName"  = $_.expandedproperties.principal.displayName
                    "PrincipalEmail" = $_.expandedproperties.principal.email;
                    "PrincipalType"  = $_.expandedproperties.principal.type;
                    "PrincipalId"    = $_.expandedproperties.principal.id;
                    "RoleName"       = $_.expandedproperties.roleDefinition.displayName;
                    "RoleType"       = $_.expandedproperties.roleDefinition.type;
                    "RoleId"         = $_.expandedproperties.roleDefinition.id;
                    "ScopeId"        = $_.expandedproperties.scope.id;
                    "ScopeName"      = $_.expandedproperties.scope.displayName;
                    "ScopeType"      = $_.expandedproperties.scope.type;
                    "Status"         = $_.Status;
                    "createdOn"      = $_.createdOn
                    "startDateTime"  = $_.startDateTime
                    "endDateTime"    = $end
                    "updatedOn"      = $_.updatedOn
                    "memberType"     = $_.memberType
                    "id"             = $id
                }


                $obj = New-Object pscustomobject -Property $properties
                $return += $obj
            }
        }

        if ($PSBoundParameters.Keys.Contains('summary')) {
            $return = $return | Select-Object scopeid, rolename, roletype, principalid, principalName, principalEmail, PrincipalType, status, startDateTime, endDateTime
        }        if ($PSBoundParameters.Keys.Contains('atBellowScope')) {
            $return = $return | Where-Object { $($_.scopeid).Length -gt $scope.Length }
        }

        Write-Output "$($return.Count) eligible assignment(s) found for scope $scope"
        return $return
    }
    catch {
        MyCatch $_
    }
}
