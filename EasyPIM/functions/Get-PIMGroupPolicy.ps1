<#
.Synopsis
Get member or owner PIM settings for a group

.Description
Get member or owner PIM settings for a group

.PARAMETER tenantID
Tenant ID

.PARAMETER GroupID
Id of the group to check

.PARAMETER GroupName
Search for the group by name

.PARAMETER type
owner or member

.Example
PS> Get-PIMGroupPolicy -tenantID $tenantID -groupID $gID -type member

show curent config for the member role of the group $gID
.Example
PS> Get-PIMGroupPolicy -tenantID $tenantID -groupname "Mygroup" -type owner

show curent config for the owner role of the group "Mygroup"

.Link
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-rest-api
    https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview
    Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
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

        #fix #77
        elseif (!( $PSBoundParameters.ContainsKey('groupID'))) {
            throw "You must provide a groupID or a groupName"
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
