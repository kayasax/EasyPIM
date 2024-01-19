<#
      .Synopsis
       Rule for activation requirement
      .Description
       rule 2 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
      .Parameter ActivationRequirement
       value can be "None", or one or more value from "Justification","Ticketing","MultiFactoAuthentication"
       WARNING options are case sensitive!
      .EXAMPLE
        PS> Set-Activationrequirement "Justification"

        A justification will be required to activate the role
      
      .Link
     
      .Notes
      	
#>
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
