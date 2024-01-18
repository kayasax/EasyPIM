function Set-ActivationRequirement($ActivationRequirement) {
    write-verbose "Set-ActivationRequirement : $($ActivationRequirement.length)"
    if (($ActivationRequirement -eq "None") -or ($ActivationRequirement[0].length -eq 0 )) {
        #if none or a null array
        write-verbose "requirement is nul"
        $enabledRules = "[],"
    }
    else {
        write-verbose "requirement is NOT nul"
        $formatedRules = '['
            
        $ActivationRequirement | ForEach-Object {
            $formatedRules += '"'
            $formatedRules += "$_"
            $formatedRules += '",'
        }
        #remove last comma
        $formatedRules = $formatedRules -replace “.$”

        $formatedRules += "],"
        $enabledRules = $formatedRules
        #Write-Verbose "************* $enabledRules "
    }
            
    $properties = '{
                "enabledRules": '+ $enabledRules + '
                "id": "Enablement_EndUser_Assignment",
                "ruleType": "RoleManagementPolicyEnablementRule",
                "target": {
                    "caller": "EndUser",
                    "operations": [
                        "All"
                    ],
                    "level": "Assignment",
                    "targetObjects": [],
                    "inheritableSettings": [],
                    "enforcedSettings": []
                }
            }'

    return $properties
}
