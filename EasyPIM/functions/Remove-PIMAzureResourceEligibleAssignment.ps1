<#
    .Synopsis
    Remove an eligible assignement at the provided scope
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
    .Parameter principalName
    Display name, UPN, object ID, or appId of the principal. Will be resolved to principalID when provided.
    .Parameter rolename
    name of the role to assign
    .Parameter justification
    justification


    .Example
    PS> Remove-PIMAzureResourceEligibleAssigment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092

    Remove the eligible assignment for the role Arcpush and principal id 3604fe63-cb67-4b60-99c9-707d46ab9092

    PS> Remove-PIMAzureResourceEligibleAssigment -tenantID $tenantID -scope "/subscriptions/$subscriptionId/resourceGroups/demo-rg" -rolename "Reader" -principalName "group@contoso.com"

    Resolve the provided principal name to its object ID before removing the eligible assignment.

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function Remove-PIMAzureResourceEligibleAssignment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding(DefaultParameterSetName = 'ByPrincipalId')]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'ByPrincipalName')]
        [String]
        # Entra ID tenantID
        $tenantID,

        [Parameter(Position = 1, ParameterSetName = 'ByPrincipalId')]
        [Parameter(Position = 1, ParameterSetName = 'ByPrincipalName')]
        [String]
        # subscription ID
        $subscriptionID,

        [Parameter(ParameterSetName = 'ByPrincipalId')]
        [Parameter(ParameterSetName = 'ByPrincipalName')]
        [String]
        # scope if not at the subscription level
        $scope,

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
        # justification (will be auto generated if not provided)
        $justification

    )

    try {
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            if (!($PSBoundParameters.Keys.Contains('subscriptionID'))) {
                throw "ERROR : You must provide a subsciption ID or a scope, exiting."
            }
            $scope = "/subscriptions/$subscriptionID"
        }
        $script:tenantID = $tenantID

        if ($PSCmdlet.ParameterSetName -eq 'ByPrincipalName') {
            $resolvedPrincipal = $null
            try {
                $resolvedPrincipal = Resolve-EasyPIMPrincipal -PrincipalIdentifier $principalName -AllowDisplayNameLookup -AllowAppIdLookup -ErrorContext 'Remove-PIMAzureResourceEligibleAssignment'
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
                $assignments = Get-PIMAzureResourceEligibleAssignment -tenantID $tenantID -scope $scope -includeFutureAssignments |
                    Where-Object { $_ -isnot [string] } |
                    Where-Object { $_.RoleName -eq $rolename -and $_.PrincipalName -match [regex]::Escape($principalName) }
                $candidateIds = $assignments | Select-Object -ExpandProperty PrincipalId -Unique

                if (-not $candidateIds -or $candidateIds.Count -eq 0) {
                    throw "No eligible assignment found matching principalName '$principalName' for role '$rolename' at scope '$scope'. Provide -principalID or ensure the name matches an eligible assignment."
                }

                if ($candidateIds.Count -gt 1) {
                    throw "Multiple eligible assignments matched principalName '$principalName' for role '$rolename'. Provide -principalID or refine the name to a unique match."
                }

                $principalID = $candidateIds[0]
                Write-Verbose "Resolved principalName '$principalName' via assignment lookup to object ID '$principalID'."
            }
        }

        $ARMhost = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
        $ARMendpoint = "$($ARMhost.TrimEnd('/'))/$scope/providers/Microsoft.Authorization"

        #1 check if there is a request for future assignment, in that case we need to cancel the request
        write-verbose "Checking if there is a future assignment for $principalID and $rolename at $scope"
        $response = get-pimazureResourceEligibleAssignment -tenantID $tenantID -scope $scope -includeFutureAssignments | Where-Object { $_.principalID -eq "$principalID" -and $_.rolename -eq "$rolename" }
        if ( !($null -eq $response) -and $response.status -ne "Provisioned" ) { #only non provisioned assignment can be canceled, else we need an admin remove
            Write-Verbose "Found a future assignment, we need to cancel it"
            $restURI = "$ARMendpoint/roleEligibilityScheduleRequests/$( $response.id.Split('/')[-1] )/cancel?api-version=2020-10-01"
            $response = invoke-arm -restURI $restURI -method POST -body $null
            Write-Host "SUCCESS : Future assignment canceled!"
            return $response
        }
        else {
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


            if (!($PSBoundParameters.Keys.Contains('justification'))) {
                $justification = "Removed from EasyPIM module by  $($(get-azcontext).account)"
            }

            $type = "null"


            $body = '
{
    "properties": {
        "principalId": "'+ $principalID + '",
        "roleDefinitionId": "'+ $roleID + '",
        "requestType": "AdminRemove",
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
            Write-Host "SUCCESS : Assignment removed!"
            return $response
        }


    }
    catch { MyCatch $_ }
}
