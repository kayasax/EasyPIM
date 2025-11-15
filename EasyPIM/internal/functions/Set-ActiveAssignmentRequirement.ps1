<#
      .Synopsis
       Rule for active assignment requirement (Rule #7 - Enablement_Admin_Assignment)
      .Description
       Configures requirements when admins create ACTIVE (not eligible) role assignments.
       This is Rule #7 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
       
       Note: This is different from Rule #2 (Enablement_EndUser_Assignment) which controls end-user ACTIVATION.
       Rule #7 supports only Justification and MFA. Ticketing is only available for Rule #2 (activation).
      .Parameter ActiveAssignmentRequirement
       value can be "None", or one or more value from "Justification","MultiFactorAuthentication"
       WARNING: Options are case sensitive!
       Reference: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules (Rule #7)
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

    # Filter to allowed admin enablement rules for Rule #7 (Enablement_Admin_Assignment)
    # Allowed: Justification, MultiFactorAuthentication (Ticketing is ONLY for Rule #2 - activation)
    # Reference: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules (Rule #7)
    $allowedAdmin = @('Justification','MultiFactorAuthentication')
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
