<#
.Synopsis
Approver notification when an elligible assignment is created
.Description
correspond to rule 11 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_EligibleAssignment_Approver
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER EntraRole
set to true if the rule is for an Entra role
.Example
PS> Set-Notification_EligibleAssignment_Approver -Notification_EligibleAssignment_Approver @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to approvers  when elligible assignment is created
.Link

.Notes
#>
function Set-Notification_EligibleAssignment_Approver($Notification_EligibleAssignment_Approver, [switch]$EntraRole) {
    #write-verbose "function Set-Notification_EligibleAssignment_Approver"

    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
    "isDefaultRecipientsEnabled": '+ ($Notification_EligibleAssignment_Approver.isDefaultRecipientEnabled).ToString().ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Approver.recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Approver_Admin_Eligibility",
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
        }'

    if($EntraRole){
        $rule = '
        {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Approver_Admin_Eligibility",
            "notificationType": "Email",
            "recipientType": "Approver",
            "isDefaultRecipientsEnabled": '+ ($Notification_EligibleAssignment_Approver.isDefaultRecipientEnabled).ToString().ToLower() + ',
            "notificationLevel": "'+ $Notification_EligibleAssignment_Approver.notificationLevel + '",
            "notificationRecipients": ['
            if( ( $Notification_EligibleAssignment_Approver.recipients |Measure-Object |Select-Object -ExpandProperty count) -gt 0){
                $Notification_EligibleAssignment_Approver.recipients | ForEach-Object {
                    $rule += '"' + $_ + '",'
                }
                $rule = $rule -replace ".$"
            }
        $rule += '],
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
    return $rule
}
