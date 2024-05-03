[CmdletBinding()]
param (
)


try{
    import-module 'C:\users\loicmichel\OneDrive - Microsoft\WIP\EASYPIM\EasyPIM\EasyPIM.psm1' -Force
    $tenantID="8d4fd732-58aa-4643-8cae-974854a66a2d"
    $subscriptionID="eedcaa84-3756-4da9-bf87-40068c3dd2a2"

    write-host "get-PIMEntraRolePolicy -tenantID $tenantID -rolename testrole"
    get-PIMEntraRolePolicy -tenantID $tenantID -rolename "testrole"

    write-host 'Set-PIMEntraRolePolicy -tenantID $tenantID -rolename "testrole" -ActivationDuration "PT12H30M"'
    Set-PIMEntraRolePolicy -tenantID $tenantID -rolename "testrole" -ActivationDuration "PT12H30M"

    write-host 'Set-PIMEntraRolePolicy -tenantID $tenantID -rolename "testrole" -Notification_eligibleAssignment_Alert  @{"isDefaultRecipientEnabled"="false"; "notificationLevel"="Critical";"Recipients" = @("eligibleassignmentalert@domain.com","email2@domain.com")}'
    Set-PIMEntraRolePolicy -tenantid $tenantid -Verbose -rolename "testrole" -Notification_eligibleAssignment_Alert  @{"isDefaultRecipientEnabled"="false"; "notificationLevel"="Critical";"Recipients" = @("eligibleassignmentalert@domain.com","email2@domain.com")}


    write-host "get-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionId -rolename webmaster"
    get-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionId -rolename "webmaster"

"SUCCEEDED!!!!!"


}
catch{

    "FAILED!!!!!"
    $_
}

