<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMAzureResourcePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description

Get-PIMAzureResourcePolicy will use the ARM REST APIs to retrieve the settings of the role at the subscription scope

.PARAMETER tenantID
Tenant ID

.PARAMETER subscriptionID
Subscription ID

.PARAMETER rolename
Name of the role to check

.Example
       PS> Get-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionID -rolename "contributor","webmaster"

       show curent config for the roles contributor and webmaster at the subscriptionID scope :

.Link
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-rest-api
    https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview
    Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Get-PIMAzureResourcePolicy {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([PSCustomObject])]
    param (

        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(ParameterSetName = 'Default',Position = 1, Mandatory = $true)]
        [System.String]
        # Subscription ID
        $subscriptionID,

        [Parameter(ParameterSetName = 'Scope',Position = 1, Mandatory = $true)]
        [System.String]
        $scope,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.String[]]
        # Array of role name
        $rolename

    )
    try {
        $script:tenantID = $tenantID

        Write-Verbose "Get-PIMAzureResourcePolicy start with parameters: subscription => $subscriptionID, rolename=> $rolename"
        #defaut scope = subscription
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            $scope = "subscriptions/$subscriptionID"
        }

        $out = @()
        $rolename | ForEach-Object {

            #get curent config
            $config = get-config $scope $_ $null $script:tenantID
            $out += $config
        }
        Write-Output $out -NoEnumerate
    }
    catch {
        MyCatch $_
    }

}
