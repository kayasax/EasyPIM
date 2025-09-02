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
            # Always warn for explicit PT0S values - these are genuinely problematic
            Write-Warning "[PT0S Prevention] MaximumActiveAssignmentDuration '$duration' would result in PT0S - using business fallback P180D"
            $MaximumActiveAssignmentDuration = "P180D"
        }
    } elseif ([string]::IsNullOrWhiteSpace($MaximumActiveAssignmentDuration)) {
        # Handle missing duration based on permanent assignment policy
        if ($AllowPermanentActiveAssignment -eq $true -or $AllowPermanentActiveAssignment -eq "true") {
            # Silent: User intended permanent, no duration limit needed
            Write-Verbose "[PT0S Prevention] No duration limit needed (permanent active assignment allowed)"
        } else {
            # Verbose warning: We're applying a business rule fallback when permanent not allowed
            Write-Verbose "[PT0S Prevention] Applied P180D fallback for empty MaximumActiveAssignmentDuration (permanent not allowed)"
            $MaximumActiveAssignmentDuration = "P180D"
        }
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
