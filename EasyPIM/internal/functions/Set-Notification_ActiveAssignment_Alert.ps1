<#
.Synopsis
admin notification when an active assignment is created
.Description
correspond to rule 12 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_ActiveAssignment_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER EntraRole
set to true if the rule is for an Entra role
.Example
PS> Set-Notification_ActiveAssignment_Alert -Notification_ActiveAssignment_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to admin when active assignment is created
.Link

.Notes
#>
function Set-Notification_ActiveAssignment_Alert($Notification_ActiveAssignment_Alert, [switch]$EntraRole) {
    $rule = '
    {
    "notificationType": "Email",
    "recipientType": "Admin",
    "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
    "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
    "notificationRecipients": [
    '
    $Notification_ActiveAssignment_Alert.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }
    $rule = $rule -replace ",$" # remove the last comma
    $rule += '
    ],
    "id": "Notification_Admin_Admin_Assignment",
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

    if($EntraRole){
        $rule='
        {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Admin_Admin_Assignment",
            "notificationType": "Email",
            "recipientType": "Admin",
            "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
            "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
            "notificationRecipients": [
                '
            if( ($Notification_ActiveAssignment_Alert.Recipients |Measure-Object |Select-Object -expand count) -gt 0 ){
                $Notification_ActiveAssignment_Alert.Recipients | ForEach-Object {
                    $rule += '"' + $_ + '",'
                }
                $rule = $rule -replace ".$"
            }


                $rule += '
            ],
            "target": {
                "caller": "Admin",
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
