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
    use scope parameter if you want to work at other scope than a subscription
    .Parameter summary
    When enabled will return the most useful information only
    .Parameter atBellowScope
    Will return only the assignment defined at lower scopes
    
    .Example
    PS> Get-PIMAzureResourceEligibleAssignment -tenantID $tid -subscriptionID -subscription $subscription

    List active assignement at the subscription scope.


    .Link
    https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-assign-roles
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
     
function Get-PIMAzureResourceEligibleAssignment {
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
        [switch]
        # select the most usefull info only
        $summary,
        [switch]
        # return only assignment defined at a lower scope
        $atBellowScope
    )

    if (!($PSBoundParameters.Keys.Contains('scope'))) {
        $scope = "/subscriptions/$subscriptionID"
    }
    $restURI = "https://management.azure.com/$scope/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01"

    $script:tenantID=$tenantID

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
    }
    if ($PSBoundParameters.Keys.Contains('atBellowScope')) {
        $return = $return | Where-Object { $($_.scopeid).Length -gt $scope.Length }
    }
    return $return
}