<#
    .Synopsis
    Copy eligible assignement from one user to another
    .Description
     https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Parameter tenantID
    EntraID tenant ID
    .Parameter subscriptionID
    subscription ID
    .Parameter scope
    use scope parameter if you want to work at other scope than a subscription
    .PARAMETER from
    userprincipalname or objectID of the source object
    .Parameter to
    userprincipalname or objectID of the destination object
       
    .Example
    PS> Copy-PIMAzureResourceEligibleAssignment -tenantID $tid -subscriptionID -subscription $subscription -from user1@contoso.com -to user2@contoso.com

    Copy eligible assignement from user1 to user2

    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
     
function Copy-PIMAzureResourceEligibleAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        [Parameter(Position = 1)]
        [String]
        $subscriptionID,
        [Parameter()]
        [String]
        $scope,
        [Parameter(Mandatory = $true)]
        [String]
        $from,
        [Parameter(Mandatory = $true)]
        [String]
        $to
    )

    try {
        
        $script:tenantID = $tenantID
        
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            $scope = "/subscriptions/$subscriptionID"
        }
        # issue #23: due to a bug with the API regarding the membertype, we will use RoleEligibilitySchedulesInstance instead of RoleEligibilitySchedule
        # the downside is we will not get assignment with a future start date
        if ($PSBoundParameters.Keys.Contains('includeFutureAssignments')) {
            $restURI = "https://management.azure.com/$scope/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01"
        }
        else {
            $restURI = "https://management.azure.com/$scope/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01"
        }

        #convert UPN to objectID
        if ($from -match ".+@.*\..+") {
            #if this is a upn we will use graph to get the objectID
            try {
                $resu = invoke-graph -endpoint "users/$from" -Method GET -version "beta"
                $from = $resu.id
            }
            catch {
                Write-Warning "User $from not found in the tenant"
                return
            }
                
        }
         
        if ($to -match ".+@.*\..+") {
            #if this is a upn we will use graph to get the objectID
            try {
                $resu = invoke-graph -endpoint "users/$to" -Method GET -version "beta"
                $to = $resu.id
            }
            catch {
                Write-Warning "User $to not found in the tenant"
                return
            }
                
        }
            
        $assignments=get-PIMAzureResourceEligibleAssignment -tenantID $tenantID -scope $scope -assignee $from
        $assignments | ForEach-Object {
            Write-Verbose "Copying assignment from $from to $to at scope $($_.scopeId) with role $($_.rolename)"
            New-PIMAzureResourceEligibleAssignment -tenantID $tenantID -subscriptionID $subscriptionID -scope $_.scopeId -rolename $_.rolename -principalID $to
        }

    }
    catch {
        MyCatch $_
    }
}