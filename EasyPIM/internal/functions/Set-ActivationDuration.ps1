<#
    .Synopsis
    Rule for maximum activation duration
    .Description
    rule 1 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
    .Parameter ActivationDuration
    Maximum activation duration.  Duration ref: https://en.wikipedia.org/wiki/ISO_8601#Durations
    .PARAMETER entraRole
    Enable if we configure an Entra role
    .EXAMPLE
    PS> Set-ActivationDuration "PT8H"

    limit the activation duration to 8 hours

    .Link

    .Notes

#>
function Set-ActivationDuration ($ActivationDuration, [switch]$entraRole) {
    # Set Maximum activation duration
    if ( ($null -ne $ActivationDuration) -and ("" -ne $ActivationDuration) ) {
        Write-Verbose "Editing Activation duration : $ActivationDuration"
        $properties = @{
            "isExpirationRequired" = "true";
            "maximumDuration"      = "$ActivationDuration";
            "id"                   = "Expiration_EndUser_Assignment";
            "ruleType"             = "RoleManagementPolicyExpirationRule";
            "target"               = @{
                "caller"     = "EndUser";
                "operations" = @("All")
            };
            "level"                = "Assignment"
        }

        $rule = $properties | ConvertTo-Json
        if ($entraRole) {
            $rule = '
           {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
            "id": "Expiration_EndUser_Assignment",
            "isExpirationRequired": true,
            "maximumDuration": "'+ $ActivationDuration + '",
            "target": {

                "caller": "EndUser",
                "operations": [
                    "All"
                ],
                "level": "Assignment",
                "inheritableSettings": [],
                "enforcedSettings": []
            }
        }'
        }
        #update rules if required
        return $rule
    }
}
