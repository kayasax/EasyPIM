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
function Set-ActivationRequirement($ActivationRequirement, [switch]$entraRole) {
        Write-Verbose "Set-ActivationRequirement : $($ActivationRequirement.length)"

                # Normalise to string[] (split comma-separated strings, preserve arrays)
                if ($null -eq $ActivationRequirement) { $ActivationRequirement = @() }
                elseif ($ActivationRequirement -is [string]) {
                        if ($ActivationRequirement -match ',') { $ActivationRequirement = ($ActivationRequirement -split ',') } else { $ActivationRequirement = @($ActivationRequirement) }
                }
                elseif (-not ($ActivationRequirement -is [System.Collections.IEnumerable])) { $ActivationRequirement = @($ActivationRequirement) }

        # Entra normalization: treat 'MFA' alias as MultiFactorAuthentication, but preserve MFA unless AC is enabled
        if ($entraRole -and $ActivationRequirement.Count -gt 0) {
                # Normalize MFA alias and trim whitespace, but do NOT remove MultiFactorAuthentication 
                # (MFA removal should only happen when Authentication Context is explicitly enabled)
                $ActivationRequirement = @($ActivationRequirement | ForEach-Object { 
                    $item = $_.ToString().Trim()
                    if ($item -eq 'MFA') { 'MultiFactorAuthentication' } else { $item }
                } | Where-Object { $_ })
        }

        # Empty or explicit None -> empty array
        if ($ActivationRequirement.Count -eq 0 -or ($ActivationRequirement.Count -eq 1 -and ($ActivationRequirement[0] -eq '' -or $ActivationRequirement[0] -eq 'None'))) {
                Write-Verbose 'Activation requirement is empty/None'
                $enabledRulesJson = '[]'
        }
        else {
                # Trim whitespace and filter empties
                $clean = $ActivationRequirement | Where-Object { $_ -and $_.Trim().Length -gt 0 } | ForEach-Object { $_.Trim() }
                # Build each quoted element first to avoid operator precedence issues with -join
                $ruleItems = $clean | ForEach-Object { '"{0}"' -f $_ }
                $enabledRulesJson = '[' + ($ruleItems -join ',') + ']'
        }

        # Build common JSON fragment. We return a single rule object; callers join objects with commas.
                if ($entraRole) {
                                # Using single-quoted here-string to avoid unintended interpolation; we manually inject $enabledRulesJson after.
                                $properties = @'
{
        "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule",
        "enabledRules": __ENABLED_RULES_PLACEHOLDER__,
        "id": "Enablement_EndUser_Assignment",
        "target": {
                "caller": "EndUser",
                "operations": [ "All" ],
                "level": "Assignment",
                "inheritableSettings": [],
                "enforcedSettings": []
        }
}
'@
                }
                else {
                                $properties = @'
{
        "enabledRules": __ENABLED_RULES_PLACEHOLDER__,
        "id": "Enablement_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyEnablementRule",
        "target": {
                "caller": "EndUser",
                "operations": [ "All" ],
                "level": "Assignment",
                "targetObjects": [],
                "inheritableSettings": [],
                "enforcedSettings": []
        }
}
'@
                }
                # Inject the enabled rules JSON (kept outside the here-string to avoid escaping complexity)
                $properties = $properties -replace '__ENABLED_RULES_PLACEHOLDER__', $enabledRulesJson
        return $properties
}
