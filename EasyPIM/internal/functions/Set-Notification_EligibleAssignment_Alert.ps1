<#
.Synopsis
admin notification when an elligible assignment is created
.Description
correspond to rule 9 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_ActiveAssignment_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER EntraRole
set to true if the rule is for an Entra role
.Example
PS> Set-Notification_EligibleAssignment_Alert -Notification_EligibleAssignment_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to admin when elligible assignment is created
.Link

.Notes
#>
function Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert, [switch]$EntraRole) {
    write-verbose "Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert)"

    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Alert.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }
    $rule = $rule -replace ".$"
    $rule += '
        ],
        "id": "Notification_Admin_Admin_Eligibility",
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
        "id": "Notification_Admin_Admin_Eligibility",
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
            '
            $Notification_EligibleAssignment_Alert.Recipients | ForEach-Object {
                $rule += '"' + $_ + '",'
            }
            $rule = $rule -replace ".$"
            $rule += '
        ],
        "target": {
            "caller": "Admin",
            "operations": [
                "All"
            ],
            "level": "Eligibility",
            "inheritableSettings": [],
            "enforcedSettings": []
        }
    }
    '
}

    write-verbose "end function notif elligible alert"
    return $rule
}
