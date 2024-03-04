<#
    .Synopsis
    Define if approval is required to activate a role, and who are the approvers
    .Description
    rule 4 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
    .Parameter ApprovalRequired
    Do we need an approval to activate a role?
    .Parameter Approvers
    Who is the approver?
    .Parameter EntraRole
    Set to $true when editing an Entra Role
    .EXAMPLE
    PS> Set-Approval -ApprovalRequired $true -Approvers @(@{"Id"=$UID;"Name"="John":"Type"="user"}, @{"Id"=$GID;"Name"="Group1":"Type"="group"})

    define John and Group1 as approvers and require approval
    
    .Link
    
    .Notes
    
#>
function Set-Approval ($ApprovalRequired, $Approvers, [switch]$entraRole) {
    Write-Verbose "Set-Approval"
    if ($null -eq $Approvers) { $Approvers = $script:config.Approvers }
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
            "targetObjects": null
                
            },
            

            "inheritableSettings": null,
            "enforcedSettings": null
        
        }}'


if($entraRole){
    $rule='
    {
        "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule",
        "id": "Approval_EndUser_Assignment",
        "target": {
            "caller": "EndUser",
            "operations": [
                "all"
            ],
            "level": "Assignment",
            "inheritableSettings": [],
            "enforcedSettings": []
        },
        "setting": {
            "isApprovalRequired": '
            $rule+=$req
            $rule+=',
            "isApprovalRequiredForExtension": false,
            "isRequestorJustificationRequired": true,
            "approvalMode": "SingleStage",
            "approvalStages": [
                {
                    "approvalStageTimeOutInDays": 1,
                    "isApproverJustificationRequired": true,
                    "escalationTimeInMinutes": 0,
                    "isEscalationEnabled": false,
                    "primaryApprovers": ['
                        if ($null -ne $Approvers) {
                            #at least one approver required if approval is enable
                           
                            $cpt = 0
                            $Approvers | ForEach-Object {
                                #write-host $_
                                $id = $_.Id
                                $name = $_.Name
                                ##$type = $_.Type
                    
                                if ($cpt -gt 0) {
                                    $rule += ","
                                }
                                $rule += '
                                {
                                    "@odata.type": "#microsoft.graph.singleUser",
                                    "isBackup": false,
                                    "id": "'+ $id + '",
                                    "description": "'+ $name + '",
                                }
                                '
                                $cpt++
                            }
                    
                            $rule += '
                                
                        
                    ],
                    "escalationApprovers": []
                }
            ]
        }
    }'
}
}
    return $rule
}
