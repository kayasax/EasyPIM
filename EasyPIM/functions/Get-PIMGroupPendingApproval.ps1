<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMGroupPolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description
 
Get-PIMGroupPendingApproval will use the Microsoft Graph APIs to retrieve the requests pending your approval

.PARAMETER tenantID
Tenant ID

.Example
       PS> Get-PIMGroupPendingApproval -tenantID $tenantID

       show pending request you can approve
    
.Link
   
.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Get-PIMGroupPendingApproval{
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
        
        $endpoint="identityGovernance/privilegedAccess/group/assignmentScheduleRequests/filterByCurrentUser(on='approver')?`$filter=status eq 'PendingApproval'"
        $response = Invoke-Graph -Endpoint $endpoint -Method "GET"

        $out = @()
        
        $pendingApproval = $response.value
        
        if ($null -ne $pendingApproval) {
            $pendingApproval | ForEach-Object {
                $details=invoke-mgGraphRequest $("https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests/"+$_.id) -Method get
                #$details
                $principalDisplayName = invoke-mgGraphRequest $("https://graph.microsoft.com/v1.0/directoryobjects/"+$details.Principalid+"/") -Method get
                $groupDisplayName = invoke-mgGraphRequest $("https://graph.microsoft.com/v1.0/directoryobjects/"+$details.Groupid+"/") -Method get

                
                $request = @{
                    "principalId"          = $details.Principalid;
                    "principalDisplayname" = $principalDisplayName.displayName;
                    "groupId"               = $details.groupId;
                    "groupDisplayname"      = $groupDisplayName.displayName;
                    "role"               = $details.AccessID;
                    "status"               = $details.status;
                    "startDateTime"        = $details.CreatedDateTime;
                    "ticketInfo"           = $details.ticketInfo;
                    "justification"        = $details.justification;
                    "approvalId"           = $details.approvalId;
                    "createdOn"            = $details.createdDateTime;
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