<#
      .Synopsis
       Rule for active assignment requirement
      .Description
       rule 2 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
      .Parameter ActiveAssignmentRequirement
       value can be "None", or one or more value from "Justification","MultiFactoAuthentication"
       WARNING options are case sensitive!
      .EXAMPLE
        PS> Set-ActiveAssignmentRequirement "Justification"

        A justification will be required to activate the role

      .Link

      .Notes

#>
function Set-ActiveAssignmentRequirement($ActiveAssignmentRequirement, [switch]$entraRole) {
    write-verbose "Set-ActiveAssignmentRequirementt : $($ActiveAssignmentRequirement.length)"
    # Normalize to array
    if ($null -eq $ActiveAssignmentRequirement) { $ActiveAssignmentRequirement = @() }
    elseif ($ActiveAssignmentRequirement -is [string]) {
        if ($ActiveAssignmentRequirement -match ',') { $ActiveAssignmentRequirement = ($ActiveAssignmentRequirement -split ',') } else { $ActiveAssignmentRequirement = @($ActiveAssignmentRequirement) }
    }

    # Filter to allowed admin enablement rules only (no MFA on Admin assignment)
    $allowedAdmin = @('Justification','Ticketing')
    $ActiveAssignmentRequirement = @($ActiveAssignmentRequirement | Where-Object { $_ -and ($allowedAdmin -contains $_.Trim()) })

    if (($ActiveAssignmentRequirement -eq "None") -or ($ActiveAssignmentRequirement.Count -eq 0)) {
        #if none or a null array
        write-verbose "requirement is null"
        $enabledRules = "[],"
    }
    else {
        write-verbose "requirement is NOT null"
        $formatedRules = '['

        $ActiveAssignmentRequirement | ForEach-Object {
            $formatedRules += '"'
            $formatedRules += "$_"
            $formatedRules += '",'
        }
        #remove last comma
        $formatedRules = $formatedRules -replace ",$"

        $formatedRules += "],"
        $enabledRules = $formatedRules
        #Write-Verbose "************* $enabledRules "
    }

    $properties = '{
                "enabledRules": '+ $enabledRules + '
                "id": "Enablement_Admin_Assignment",
                "ruleType": "RoleManagementPolicyEnablementRule",
                "target": {
                    "caller": "Admin",
                    "operations": [
                        "All"
                    ],
                    "level": "Assignment",
                    "targetObjects": [],
                    "inheritableSettings": [],
                    "enforcedSettings": []
                }
            }'
    if ($entraRole) {
                $properties = '
               {
                "@odata.type" : "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule",
                "enabledRules": '+ $enabledRules + '
                "id": "Enablement_Admin_Assignment",
                "target": {
                    "caller": "Admin",
                    "operations": [
                        "All"
                    ],
                    "level": "Assignment",
                    "inheritableSettings": [],
                    "enforcedSettings": []
                }
            }'
            }
    return $properties
}
