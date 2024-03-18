<#
      .Synopsis
       Define if approval is required to activate a role, and who are the approvers
      .Description
       rule 4 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
      .Parameter ApprovalRequired
       Do we need an approval to activate a role?
      .Parameter Approvers
        Who is the approver?
        .PARAMETER entrarole
        set to true if configuration is for an entra role
      .EXAMPLE
        PS> Set-Approval -ApprovalRequired $true -Approvers @(@{"Id"=$UID;"Name"="John":"Type"="user"}, @{"Id"=$GID;"Name"="Group1":"Type"="group"})

        define John and Group1 as approvers and require approval
      
      .Link
     
      .Notes
      	
#>
function Set-ApprovalFromCSV  {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApprovalRequired,
        [Parameter(Mandatory=$false)]
        [string[]]$Approvers,
        [Parameter(Mandatory=$false)]
        [switch]$entraRole
    )
    write-verbose "Set-ApprovalFromCSV"
    if ($null -eq $Approvers) { $Approvers = $script:config.Approvers }
if ($ApprovalRequired -eq "FALSE") { $req = "false" }else { $req = "true" }
    
    if (!$entraRole) {
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
    }

    if ($entraRole) {
        
        $rule = '
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
        $rule += $req
        $rule += ',
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
        if (($null -ne $Approvers) -and ("" -ne $Approvers)) {
            #at least one approver required if approval is enable
                                   
            $cpt = 0
            # write-verbose "approvers: $approvers"
            $Approvers = $Approvers -replace ",$" # remove the last comma
            #then turn the sting into an array of hash table
            $list = Invoke-Expression $($c.Approvers -replace ",$")
            $list | ForEach-Object {
                $id = $_.id
                $name = $_.description
                #$type = $_.userType
                        
                if ($cpt -gt 0) {
                    $rule += ","
                }
            
                $rule += '
            {
                "@odata.type": "#microsoft.graph.singleUser",
                "isBackup": false,
                "id": "'+ $id + '",
                "description": "'+ $name + '"
            }
            '
                $cpt++
            }
        }
        $rule += '
                                        
                                
                            ],
                            "escalationApprovers": []
                        }
                    ]
                }
            }'
        
    }
    return $rule
}
