<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMGroupPolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description

Approve-PIMGroupPendingApprovall will use the Microsoft Graph APIs to retrieve the requests pending your approval

.PARAMETER approvalID
approval ID from get-PIMAzureResourcePendingApproval

.PARAMETER justification
justification for the approval

.Example
       PS> approve-PIMAzureResourcePendingApproval -approvalID $approvalID -justification "I approve this request"

       Approve a pending request

.Link

.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Approve-PIMGroupPendingApproval {
    [CmdletBinding()]
    [OutputType([String])]
    param (

        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]
        # Approval ID
        $approvalID,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        # justification
        $justification

    )
    process {
        try {
            #$script:tenantID = $tenantID

            Write-Verbose "approve-PIMGroupPendingApproval start with parameters: approvalid => $approvalID, justification => $justification"

            #Get the stages:
            #in groups stageID is the same as the approvalID


            #approve the request
            #https://learn.microsoft.com/en-us/graph/api/approvalstage-update?view=graph-rest-1.0&tabs=http

            $body = '{"justification":"' + $justification + '","reviewResult":"Approve"}'
            Invoke-graph -endpoint "identityGovernance/privilegedAccess/group/assignmentApprovals/$approvalID/steps/$approvalID" -body $body -version "beta" -Method PATCH
            return "Success, request approved"

        }
        catch {
            MyCatch $_
        }
    }
}
