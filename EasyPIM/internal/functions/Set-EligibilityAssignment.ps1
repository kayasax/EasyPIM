<#
      .Synopsis
       definne the eligible assignment setting : max duration and if permanent eligibility is allowed
      .Description
       correspond to rule 5 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumEligibilityDuration
       maximum duration of an eligibility
      .Parameter AllowPermanentEligibility
       Do we allow permanent eligibility
      .Parameter EntraRole
       Set to $true if configuring entra role
      .Example
       PS> Set-EligibilityAssignment -MaximumEligibilityDuration "P30D" -AllowPermanentEligibility $false

       set Max eligibility duration to 30 days
      .Link

      .Notes
#>
function Set-EligibilityAssignment($MaximumEligibilityDuration, $AllowPermanentEligibility, [switch]$entraRole) {
    write-verbose "Set-EligibilityAssignment: $MaximumEligibilityDuration $AllowPermanentEligibility"

    # PT0S Prevention: Validate and sanitize MaximumEligibilityDuration to prevent zero duration values
    if ($MaximumEligibilityDuration) {
        $duration = [string]$MaximumEligibilityDuration
        # Check for zero duration values that would result in PT0S
        if ($duration -eq "PT0S" -or $duration -eq "PT0M" -or $duration -eq "PT0H" -or $duration -eq "P0D" -or [string]::IsNullOrWhiteSpace($duration)) {
            # Always warn for explicit PT0S values - these are genuinely problematic
            Write-Warning "[PT0S Prevention] MaximumEligibilityDuration '$duration' would result in PT0S - using business fallback P365D"
            $MaximumEligibilityDuration = "P365D"
        }
    } elseif ([string]::IsNullOrWhiteSpace($MaximumEligibilityDuration)) {
        # Handle missing duration based on permanent assignment policy
        if ($AllowPermanentEligibility -eq $true -or $AllowPermanentEligibility -eq "true") {
            # Silent: User intended permanent, no duration limit needed
            Write-Verbose "[PT0S Prevention] No duration limit needed (permanent eligibility allowed)"
        } else {
            # Verbose warning: We're applying a business rule fallback when permanent not allowed
            Write-Verbose "[PT0S Prevention] Applied P365D fallback for empty MaximumEligibilityDuration (permanent not allowed)"
            $MaximumEligibilityDuration = "P365D"
        }
    }

    $max = $MaximumEligibilityDuration

    if ( ($true -eq $AllowPermanentEligibility) -or ("true" -eq $AllowPermanentEligibility) -and ("false" -ne $AllowPermanentEligibility)) {
        $expire = "false"
        write-verbose "1 setting expire to : $expire"
    }
    else {

        $expire = "true"
        write-verbose "2 setting expire to : $expire"
    }

    $rule = '
        {
        "isExpirationRequired": '+ $expire + ',
        "maximumDuration": "'+ $max + '",
        "id": "Expiration_Admin_Eligibility",
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
if($entraRole){
  $maxField = ''
  # Normalize duration for Entra: Graph may not accept P1Y; convert to P365D when needed
  $normMax = $max
  if ($null -ne $normMax -and $normMax -match '^P\d+Y$') {
    # Extract years and convert to days (approximate 365 days per year)
    $years = [int]($normMax.TrimStart('P').TrimEnd('Y'))
    if ($years -lt 0) { $years = 0 }
    $days = $years * 365
    $normMax = "P${days}D"
  }
  if ($expire -eq 'true') {
  $maxField = '"maximumDuration": "'+ $normMax + '",'
  }
  $normMaxDisplay = if ($null -ne $normMax -and $normMax -ne '') { $normMax } else { '<none>' }
  Write-Verbose ("[Policy][Entra][Eligibility] isExpirationRequired={0} maximumDuration={1}" -f $expire, $normMaxDisplay)
  $rule='{
    "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
    "id": "Expiration_Admin_Eligibility",
    "isExpirationRequired": '+ $expire + ',
    '+ $maxField + '
    "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "inheritableSettings": [],
        "enforcedSettings": []
    }
  }'
}

    return $rule
}
