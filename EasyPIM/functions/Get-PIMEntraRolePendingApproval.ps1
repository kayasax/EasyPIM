<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMEntraRolePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description

Get-PIMEntraRolePendingApproval will use the Microsoft Graph APIs to retrieve the requests pending your approval

.PARAMETER tenantID
Tenant ID

.Example
       PS> Get-PIMEntraRolePendingApproval -tenantID $tenantID

       show pending request you can approve

.Link

.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Get-PIMEntraRolePendingApproval{
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

        $endpoint="/roleManagement/directory/roleAssignmentScheduleRequests/filterByCurrentUser(on='approver')?`$filter=status eq 'PendingApproval'"
        $response = Invoke-Graph -Endpoint $endpoint -Method "GET"

        $out = @()

        $pendingApproval = $response.value

        if ($null -ne $pendingApproval) {
            $pendingApproval | ForEach-Object {
                $role=invoke-mgGraphRequest $("https://graph.microsoft.com/v1.0/directoryRoles(roletemplateid ='"+$_.roledefinitionid+"')") -Method get
                $principalDisplayName = invoke-mgGraphRequest $("https://graph.microsoft.com/v1.0/directoryobjects/"+$_.Principalid+"/") -Method get
                $request = @{
                    "principalId"          = $_.Principalid;
                    "principalDisplayname" = $principalDisplayName.displayName;
                    "roleId"               = $_.RoleDefinitionid;

                    "roleDisplayname"      = $role.displayname;
                    "status"               = $_.status;
                    "startDateTime"        = $_.CreatedDateTime;
                    "ticketInfo"           = $_.ticketInfo;
                    "justification"        = $_.justification;
                    "scope"                = "/";
                    "approvalId"           = $_.approvalId;
                    "createdOn"            = $_.createdDateTime;
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
