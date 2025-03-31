<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMEntraRolePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description

Get-PIMAzureResourcePendingApproval will use the Microsoft Graph APIs to retrieve the requests pending your approval

.PARAMETER tenantID
Tenant ID

.Example
       PS> Get-PIMAzureResourcePendingApproval -tenantID $tenantID

       show pending request you can approve

.Link

.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Get-PIMAzureResourcePendingApproval {

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
    [CmdletBinding()]
    param (

        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID

    )
    try {
        $script:tenantID = $tenantID

        Write-Verbose "Get-PIMAzureResourcePendingApproval start with parameters: tenantID => $tenantID"

        $out = @()
        $response = invoke-AzRestMethod -Uri "https://management.azure.com/providers/Microsoft.Authorization/roleAssignmentScheduleRequests?api-version=2020-10-01&`$filter=asApprover()"
        $pendingApproval = $response.Content | convertfrom-json
        if ($null -ne $pendingApproval.value.properties) {
            $pendingApproval.value.properties | ForEach-Object {
                $request = @{
                    "principalType"        = $_.principalType;
                    "principalId"          = $_.expandedProperties.Principal.id;
                    "principalDisplayname" = $_.expandedProperties.Principal.displayName;
                    "roleId"               = $_.expandedProperties.RoleDefinition.id;
                    "roleDisplayname"      = $_.expandedProperties.RoleDefinition.displayName;
                    "status"               = $_.status;
                    "startDateTime"        = $_.scheduleInfo.startDateTime;
                    "ticketInfo"           = $_.ticketInfo;
                    "justification"        = $_.justification;
                    "scope"                = $_.Scope;
                    "approvalId"           = $_.approvalId;
                    "requestType"          = $_.requestType;
                    "createdOn"            = $_.createdOn;
                }
                $o = New-Object -TypeName PSObject -Property $request
                $out += $o
            }
        }
        if ($out.length -eq 0) {
            #write-host "No pending approval"
            return $null
        }
        return $out

    }
    catch {
        MyCatch $_
    }

}
