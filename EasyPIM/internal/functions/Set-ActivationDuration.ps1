function Set-ActivationDuration ($ActivationDuration) {
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
        #update rules if required
        return $rule
    }
}
