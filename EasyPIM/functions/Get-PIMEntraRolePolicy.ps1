<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMEntraRolePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description
 
Get-PIMEntraRolePolicy will use the Microsoft Graph APIs to retrieve the PIM settings of the role $rolename

.PARAMETER tenantID
Tenant ID

.PARAMETER rolename
Name of the role to check

.Example
       PS> Get-PIMEntraRolePolicy -tenantID $tenantID -rolename "Global Administrator","Global Reader"

       show curent config for the roles global administrator and global reader
    
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
function Get-PIMEntraRolePolicy {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID, 
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]]
        # Array of role name
        $rolename
        
    )
    try {
        $script:tenantID = $tenantID

        Write-Verbose "Get-PIMEntraRolePolicy start with parameters: tenantID => $tenantID, rolename=> $rolename"
               
        $out = @()
        $rolename | ForEach-Object {
            
            #get curent config
            $config = get-EntraRoleConfig $_
            $out += $config
        }
        Write-Output $out -NoEnumerate
    }
    catch {
        MyCatch $_
    }
    
}