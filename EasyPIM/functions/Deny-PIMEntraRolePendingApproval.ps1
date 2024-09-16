<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMEntraRolePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description
 
Deny-PIMEntraRolePendingApprovall will use the Microsoft Graph APIs to retrieve the requests pending your approval

.PARAMETER approvalID
approval ID from get-PIMAzureResourcePendingApproval

.PARAMETER justification
justification for the approval

.Example
       PS> Deny-PIMAzureResourcePendingApproval -approvalID $approvalID -justification "I Deny this request"

       Deny a pending request
    
.Link
   
.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic
    Changelog:
    Todo:
    * allow other scopes
#>
function Deny-PIMEntraRolePendingApproval {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        
        [Parameter(Position = 0, Mandatory = $true,ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true)]
        [System.String]
        # Approval ID
        $approvalID,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        # justification
        $justification
        
    )
    process{
    try {
        #$script:tenantID = $tenantID

        Write-Verbose "Deny-PIMEntraRolePendingApproval start with parameters: approvalid => $approvalID, justification => $justification"
               
        #Get the stages:
        #Role Assignment Approval Steps - List - REST API (Azure Authorization) | Microsoft Learn
        $stages=Invoke-graph -endpoint "roleManagement/directory/roleAssignmentApprovals/$approvalID/"  -Method GET -version "beta"

        $stageid=$stages.id

        #Deny the request
        #Role Assignment Approval Step - Patch - REST API (Azure Authorization) | Microsoft Learn

        $body='{"justification":"'+$justification+'","reviewResult":"Deny"}'

        Invoke-graph -endpoint "roleManagement/directory/roleAssignmentApprovals/$approvalID/steps/$stageID" -body $body -version "beta" -Method PATCH
        return "Success, request Denyd"

    }
    catch {
        MyCatch $_
    }
    
}}