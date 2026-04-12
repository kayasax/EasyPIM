<#
    .Synopsis
    Copy active assignement from one user to another
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
    PS> Copy-PIMAzureResourceActiveAssignment -tenantID $tid -subscriptionID $subscription -from user1@contoso.com -to user2@contoso.com

    Copy active assignement from user1 to user2

    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>

function Copy-PIMAzureResourceActiveAssignment {
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

        $assignments = Get-PIMAzureResourceActiveAssignment -tenantID $tenantID -scope $scope -assignee $from
        $assignments | ForEach-Object {
            Write-Verbose "Copying assignment from $from to $to at scope $($_.scopeId) with role $($_.rolename)"
            $params = @{
                tenantID       = $tenantID
                subscriptionID = $subscriptionID
                scope          = $_.scopeId
                rolename       = $_.rolename
                principalID    = $to
            }
            if ($_.endDateTime -eq "permanent") { $params.permanent = $true }
            if ($_.Condition) {
                $params.condition = $_.Condition
                if ($_.ConditionVersion) { $params.conditionVersion = $_.ConditionVersion }
            }
            New-PIMAzureResourceActiveAssignment @params
        }

    }
    catch {
        MyCatch $_
    }
}
