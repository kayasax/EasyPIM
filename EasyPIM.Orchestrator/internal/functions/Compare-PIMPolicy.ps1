function Compare-PIMPolicy {
	<#
	.SYNOPSIS
	Compares expected PIM policy settings against live policy configuration.

	.DESCRIPTION
	Performs field-by-field comparison of PIM policy settings, applying business
	rules validation and handling requirement normalization. Returns structured
	comparison results.

	.PARAMETER Type
	The type of policy being compared (EntraRole, AzureRole, Group).

	.PARAMETER Name
	The name of the role or policy being compared.

	.PARAMETER Expected
	The expected policy configuration object.

	.PARAMETER Live
	The live policy configuration from the system.

	.PARAMETER ExtraId
	Optional additional identifier (scope, group ID, etc.).

	.PARAMETER ApproverCountExpected
	Expected number of approvers when approval is required.

	.PARAMETER Results
	Reference to the results array to append to.

	.PARAMETER DriftCount
	Reference to the drift counter to increment.

	.OUTPUTS
	None. Updates the provided Results array and DriftCount reference.

	.EXAMPLE
	Compare-PIMPolicy -Type "EntraRole" -Name "Global Administrator" -Expected $expected -Live $live -Results ([ref]$results) -DriftCount ([ref]$driftCount)
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)][string]$Type,
		[Parameter(Mandatory)][string]$Name,
		[Parameter()][object]$Expected,
		[Parameter()][object]$Live,
		[Parameter()][string]$ExtraId = $null,
		[Parameter()][int]$ApproverCountExpected = $null,
		[Parameter(Mandatory)][ref]$Results,
		[Parameter(Mandatory)][ref]$DriftCount
	)

	# Fields to compare
	$fields = @(
		'ActivationDuration',
		'ActivationRequirement',
		'ApprovalRequired',
		'MaximumEligibilityDuration',
		'AllowPermanentEligibility',
		'MaximumActiveAssignmentDuration',
		'AllowPermanentActiveAssignment'
	)

	# Mapping from config names to live policy property names
	$liveNameMap = @{
		'ActivationRequirement' = 'EnablementRules'
		'MaximumEligibilityDuration' = 'MaximumEligibleAssignmentDuration'
		'AllowPermanentEligibility' = 'AllowPermanentEligibleAssignment'
	}

	$differences = @()

	foreach ($field in $fields) {
		if ($Expected.PSObject.Properties[$field]) {
			$expectedValue = $Expected.$field
			$liveProperty = $field

			# Map to live property name if needed
			if ($liveNameMap.ContainsKey($field)) {
				$liveProperty = $liveNameMap[$field]
			}

			$liveValue = $null
			if ($Live -and $Live.PSObject -and $Live.PSObject.Properties[$liveProperty]) {
				$liveValue = $Live.$liveProperty
			}

			# Handle array values
			if ($expectedValue -is [System.Collections.IEnumerable] -and -not ($expectedValue -is [string])) {
				$expectedValue = ($expectedValue | ForEach-Object { "$_" }) -join ','
			}
			if ($liveValue -is [System.Collections.IEnumerable] -and -not ($liveValue -is [string])) {
				$liveValue = ($liveValue | ForEach-Object { "$_" }) -join ','
			}

			# Special handling for activation requirements
			if ($field -eq 'ActivationRequirement' -or $field -eq 'ActiveAssignmentRequirement') {
				$expectedNormalized = Convert-RequirementValue -Value $expectedValue
				$liveNormalized = Convert-RequirementValue -Value $liveValue

				# Apply business rules validation
				$policyForBusinessRules = [PSCustomObject]@{}
				$Expected.PSObject.Properties | ForEach-Object {
					$policyForBusinessRules | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value
				}

				$businessRuleResult = Test-PIMPolicyBusinessRules -PolicySettings $policyForBusinessRules -CurrentPolicy $Live -ApplyAdjustments
				$hasBusinessRuleAdjustment = $businessRuleResult.HasChanges

				if ($hasBusinessRuleAdjustment) {
					$adjustedExpected = $businessRuleResult.AdjustedSettings.$field
					$adjustedExpectedNormalized = Convert-RequirementValue -Value $adjustedExpected

					if ($adjustedExpectedNormalized -eq $liveNormalized) {
						# This is expected behavior due to business rules, not drift
						if ($businessRuleResult.Conflicts -and $businessRuleResult.Conflicts.Count -gt 0) {
							Write-Verbose "$Name - Business rule applied: $($businessRuleResult.Conflicts[0]) (expected behavior, not drift)"
						}
						continue  # Skip adding to differences
					} else {
						# Still drift even after business rule adjustments
						$expectedNormalized = $adjustedExpectedNormalized
						$expectedValue = $adjustedExpected
					}
				}

				if ($expectedNormalized -ne $liveNormalized) {
					$displayExpected = if ($null -eq $expectedValue -or $expectedValue -eq '' -or $expectedValue -eq 'None') { 'None' } else { $expectedValue }
					$displayLive = if ($null -eq $liveValue -or $liveValue -eq '' -or $liveValue -eq 'None') { 'None' } else { $liveValue }
					$driftMessage = "{0}: expected='{1}' actual='{2}'" -f $field, $displayExpected, $displayLive

					# Add explanatory notes for business rule conflicts
					if ($hasBusinessRuleAdjustment) {
						$driftMessage += " (Note: Expected value adjusted for Authentication Context business rules)"
					}

					$differences += $driftMessage
				}
			}
			else {
				# Standard field comparison
				if ("$expectedValue" -ne "$liveValue") {
					$differences += ("{0}: expected='{1}' actual='{2}'" -f $field, $expectedValue, $liveValue)
				}
			}
		}
	}

	# Check approver count if approval is required
	if ($null -ne $ApproverCountExpected -and $Expected.PSObject.Properties['ApprovalRequired'] -and $Expected.ApprovalRequired) {
		$liveApproverCount = $null

		# Try different property names for approver count
		foreach ($approverProperty in @('Approvers', 'Approver', 'Approval', 'approval', 'ApproverCount')) {
			if ($Live.PSObject -and $Live.PSObject.Properties[$approverProperty]) {
				$approverValue = $Live.$approverProperty
				if ($approverValue -is [System.Collections.IEnumerable] -and -not ($approverValue -is [string])) {
					$liveApproverCount = @($approverValue).Count
				}
				elseif ($approverValue -match '^[0-9]+$') {
					$liveApproverCount = [int]$approverValue
				}
				if ($null -ne $liveApproverCount) { break }
			}
		}

		if ($null -ne $liveApproverCount -and $liveApproverCount -ne $ApproverCountExpected) {
			$differences += "ApproversCount: expected=$ApproverCountExpected actual=$liveApproverCount"
		}
	}

	# Determine status and update counters
	if ($differences.Count -gt 0) {
		$DriftCount.Value++
		$status = 'Drift'
	} else {
		$status = 'Match'
	}

	# Add protected role indicator to the name display
	$displayName = $Name
	if (Test-IsProtectedRole -RoleName $Name -Type $Type) {
		$displayName = "$Name [⚠️ PROTECTED]"
	}

	# Add result to the results array
	$Results.Value += [pscustomobject]@{
		Type = $Type
		Name = $displayName
		Target = $ExtraId
		Status = $status
		Differences = ($differences -join '; ')
	}
}
