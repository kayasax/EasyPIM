<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMGroupPolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description
 
Get-PIMGroupPolicy will use the Microsoft Graph APIs to retrieve the PIM settings of the role $rolename

.PARAMETER tenantID
Tenant ID

.PARAMETER GroupID
Id of the group to check

.PARAMETER GroupName
Search for the group by name

.Example
       PS> Get-PIMGroupPolicy -tenantID $tenantID -rolename "Global Administrator","Global Reader"

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
function Get-PIMGroupPolicy {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,
        
        [Parameter(Position = 1)]
        [System.String[]]
        # Array of role name
        $groupID,

        [Parameter(Position = 2)]
        [System.String]
        # Array of role name
        $groupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        #owner or member
        $type

        
    )
    try {
        $script:tenantID = $tenantID

        if ($PSBoundParameters.ContainsKey('groupname')) {
            $endpoint="/groups?`$filter=startswith(displayName,'$($groupName)')"
            $response=invoke-graph -Endpoint $endpoint
            $groupID+=$response.value.id

        }
        
                       
        $out = @()
        $groupID | ForEach-Object {
            
            #get curent config
            $config = get-GroupConfig $_ $type
            $out += $config
        }
        Write-Output $out -NoEnumerate
    }
    catch {
        MyCatch $_
    }
    
}