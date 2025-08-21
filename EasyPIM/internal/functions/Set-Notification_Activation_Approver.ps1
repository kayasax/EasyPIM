<#
      .Synopsis
       Approver notification when a role is activated
      .Description
       correspond to rule 1 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
      .Parameter Notification_Activation_Approver
      hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
      .PARAMETER entrarole
        set to true if configuration is for an entra role
      .Example
       PS> Set-Notification_Activation_Alert -Notification_Activation_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

       set the notification sent to Admins when a role is activated
      .Link

      .Notes
#>
function Set-Notification_Activation_Approver ($Notification_Activation_Approver, [switch]$entrarole) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
    "isDefaultRecipientsEnabled": '+ ($Notification_Activation_Approver.isDefaultRecipientEnabled).ToString().ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    <#
            # Cant add backup recipient for this rule

            $Notification_Activation_Approver.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        #>
    $rule += '
        ],
        "id": "Notification_Approver_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
    if($entrarole){ #cant add additional recipients for this rule
        $rule='{
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Approver_EndUser_Assignment",
            "notificationType": "Email",
            "recipientType": "Approver",
            "isDefaultRecipientsEnabled": '+ ($Notification_Activation_Approver.isDefaultRecipientEnabled).ToString().ToLower() + ',
            "notificationLevel": "'+ $Notification_Activation_Approver.notificationLevel + '",
            "notificationRecipients": [],
            "target": {
                "caller": "EndUser",
                "operations": [
                    "all"
                ],
                "level": "Assignment",
                "inheritableSettings": [],
                "enforcedSettings": []
            }
        }
        '
    }
    return $rule
}
