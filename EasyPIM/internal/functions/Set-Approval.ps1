function Set-Approval ($ApprovalRequired, $Approvers) {
    Write-Verbose "Set-Approval"       
    if ($null -eq $Approvers) { $Approvers = $config.Approvers }
    if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        
    $rule = '
        {
        "setting": {'
    if ($null -ne $ApprovalRequired) {
        $rule += '"isApprovalRequired": ' + $req + ','
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
        $rule += '
            "primaryApprovers": [
            '
        $cpt = 0    
        $Approvers | ForEach-Object {
            #write-host $_
            $id = $_.Id
            $name = $_.Name
            $type = $_.Type

            if ($cpt -gt 0) {
                $rule += ","
            }
            $rule += '
            {
                "id": "'+ $id + '",
                "description": "'+ $name + '",
                "isBackup": false,
                "userType": "'+ $type + '"
            }
            '
            $cpt++
        }

        $rule += '
            ],'
    }

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
