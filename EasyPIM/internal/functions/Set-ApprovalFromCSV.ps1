<#
      .Synopsis
       Define if approval is required to activate a role, and who are the approvers
      .Description
       rule 4 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
      .Parameter ApprovalRequired
       Do we need an approval to activate a role?
      .Parameter Approvers
        Who is the approver?
      .EXAMPLE
        PS> Set-Approval -ApprovalRequired $true -Approvers @(@{"Id"=$UID;"Name"="John":"Type"="user"}, @{"Id"=$GID;"Name"="Group1":"Type"="group"})

        define John and Group1 as approvers and require approval
      
      .Link
     
      .Notes
      	
#>
function Set-ApprovalFromCSV ($ApprovalRequired, $Approvers) {
    write-verbose "Set-ApprovalFromCSV"
    if ($null -eq $Approvers) { $Approvers = $config.Approvers }
    if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        
    $rule = '
        {
        "setting": {'
    if ($null -ne $ApprovalRequired) {
        $rule += '"isApprovalRequired":' + $req + ','
    }
       
    $rule += '
        "isApprovalRequiredForExtension": false,
        "isRequestorJustificationRequired": true,
        "approvalMode": "SingleStage",
        "approvalStages": [
            {
            "approvalStageTimeOutInDays": 1,
            "isApproverJustificationRequired": true,
            "escalationTimeInMinutes": 0,
        '

    if ($null -ne $Approvers) {
        #at least one approver required if approval is enable

        $Approvers = $Approvers -replace "@"
        $Approvers = $Approvers -replace ";", ","
        $Approvers = $Approvers -replace "=", ":"

        $rule += '
            "primaryApprovers": [
            '+ $Approvers
    }

    $rule += '
            ],'
        

    $rule += '
        "isEscalationEnabled": false,
            "escalationApprovers": null
                    }]
                 },
        "id": "Approval_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyApprovalRule",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "targetObjects": null,
            "inheritableSettings": null,
            "enforcedSettings": null
        
        }}'
    return $rule
}
