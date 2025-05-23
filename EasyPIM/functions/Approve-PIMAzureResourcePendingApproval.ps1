﻿<#
.Synopsis
EASYPIM
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind
Get-PIMEntraRolePolicy will return the policy rules (like require MFA on activation) of the selected rolename at the subscription level
Support querrying multi roles at once

.Description

Get-PIMAzureResourcePendingApproval will use the Microsoft Graph APIs to retrieve the requests pending your approval

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
function Approve-PIMAzureResourcePendingApproval {
    [CmdletBinding()]
    [OutputType([String])]
    param (

        [Parameter(Position = 0, Mandatory = $true,ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true)]
        [System.String]
        # Tenant ID
        $approvalID,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        # justification
        $justification

    )
    process{
    try {
        $script:tenantID = $tenantID

        Write-Verbose "approve-PIMAzureResourcePendingApproval start with parameters: approvalid => $approvalID, justification => $justification"

        #Get the stages:
        #Role Assignment Approval Steps - List - REST API (Azure Authorization) | Microsoft Learn
        $stages=Invoke-AzRestMethod -Uri "https://management.azure.com/$approvalID/stages?api-version=2021-01-01-preview" -Method GET

        $stageid=($stages.Content | convertfrom-json).value.id

        #approve the request
        #Role Assignment Approval Step - Patch - REST API (Azure Authorization) | Microsoft Learn

        $body='{"properties":{"justification":"'+$justification+'","reviewResult":"Approve"}}'

        Invoke-AzRestMethod -Uri "https://management.azure.com/$stageid/?api-version=2021-01-01-preview" -Payload $body -Method PUT
        return "Success, request approved"

    }
    catch {
        MyCatch $_
    }
}
}
