<#
    .Synopsis
    Rule for maximum active assignment
    .Description
    rule 6 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
    .Parameter MaximumActiveAssignmentDuration
    Maximum active assignment duration.  Duration ref: https://en.wikipedia.org/wiki/ISO_8601#Durations
    .Parameter AllowPermanentActiveAssignment
    Allow permanent active assignement ?
    .Parameter EntraRole
    set to true if the rule is for an Entra role
    .EXAMPLE
    PS> Set-ActiveAssignment -MaximumActiveAssignmentDuration "P30D" -AllowPermanentActiveAssignment $false

    limit the active assignment duration to 30 days

    .Link

    .Notes

#>
function Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment, [switch]$EntraRole) {
    write-verbose "Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment)"

    # PT0S Prevention: Validate and sanitize MaximumActiveAssignmentDuration to prevent zero duration values
    if ($MaximumActiveAssignmentDuration) {
        $duration = [string]$MaximumActiveAssignmentDuration
        # Check for zero duration values that would result in PT0S
        if ($duration -eq "PT0S" -or $duration -eq "PT0M" -or $duration -eq "PT0H" -or $duration -eq "P0D" -or [string]::IsNullOrWhiteSpace($duration)) {
            Write-Warning "[PT0S Prevention] MaximumActiveAssignmentDuration '$duration' would result in PT0S - using minimum fallback PT5M"
            $MaximumActiveAssignmentDuration = "PT5M"
        }
    } elseif ([string]::IsNullOrWhiteSpace($MaximumActiveAssignmentDuration) -and $AllowPermanentActiveAssignment -ne $true -and $AllowPermanentActiveAssignment -ne "true") {
        # If duration is empty/null but permanent is not allowed, provide fallback
        Write-Warning "[PT0S Prevention] Empty MaximumActiveAssignmentDuration with permanent not allowed - using minimum fallback PT5M"
        $MaximumActiveAssignmentDuration = "PT5M"
    }

    # Determine if expiration is required (i.e., permanent assignments are NOT allowed)
    $isPermanentAllowed = $false
    if ($AllowPermanentActiveAssignment -eq $true -or $AllowPermanentActiveAssignment -eq "true") {
        $isPermanentAllowed = $true
    }

    if ($isPermanentAllowed) {
        $expire2 = "false"  # No expiration required - permanent assignments allowed
    } else {
        $expire2 = "true"   # Expiration required - permanent assignments NOT allowed
    }

    $rule = '
        {
        "isExpirationRequired": '+ $expire2 + ',
        "maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",
        "id": "Expiration_Admin_Assignment",
        "ruleType": "RoleManagementPolicyExpirationRule",
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
    $maxField = ''
    if ($expire2 -eq 'true') {
        # expiration required -> include maximumDuration
    $maxField = '"maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",'
    }
    $rule = '
        {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
            "id": "Expiration_Admin_Assignment",
            "isExpirationRequired": '+ $expire2 + ',
            '+ $maxField + '
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
    return $rule

}
