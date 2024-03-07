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
    .Parameter rolename
    name of the role to assign
    .Parameter justification
    justification


    .Example
    PS> Remove-PIMAzureResourceEligibleAssigment -tenantID $tenantID -subscriptionID $subscriptionId -rolename "AcrPush" -principalID 3604fe63-cb67-4b60-99c9-707d46ab9092

    Remove the eligible assignment for the role Arcpush and principal id 3604fe63-cb67-4b60-99c9-707d46ab9092

    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
function Remove-PIMAzureResourceEligibleAssignment {
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

        $ARMhost = "https://management.azure.com"
        $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    
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
    catch { MyCatch $_ }
}
