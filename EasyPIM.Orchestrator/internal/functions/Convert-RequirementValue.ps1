function Convert-RequirementValue {
	<#
	.SYNOPSIS
	Normalizes activation requirement values for consistent comparison.

	.DESCRIPTION
	Converts activation requirement strings to a standardized format by:
	- Handling null/empty/none values
	- Normalizing MFA references
	- Standardizing justification references
	- Sorting and deduplicating multiple requirements

	.PARAMETER Value
	The activation requirement value to normalize.

	.OUTPUTS
	String. The normalized requirement value.

	.EXAMPLE
	$normalized = Convert-RequirementValue -Value "MFA, justification"
	# Returns: "Justification,MFA"

	.EXAMPLE
	$normalized = Convert-RequirementValue -Value "none"
	# Returns: ""
	#>
	[CmdletBinding()]
	param([Parameter()][object]$Value)

	if (-not $Value) { return '' }

	# Normalize complex types (hashtables/objects/enumerables) into a string representation
	if ($Value -is [System.Collections.IDictionary]) {
		$Value = ($Value.GetEnumerator() | ForEach-Object { $_.Value }) -join ','
	} elseif ($Value -is [pscustomobject]) {
		$Value = ($Value.PSObject.Properties | ForEach-Object { $_.Value }) -join ','
	} elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
		$Value = ($Value | ForEach-Object { "$_" }) -join ','
	}

	$v = "$Value".Trim()
	if ($v -eq '') { return '' }

	# Handle explicit "none" values
	if ($v -match '^(none|null|no(ne)?requirements?)$') { return '' }

	# Split on comma / semicolon and process each token
	$tokens = $v -split '[,;]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

	$normalized = foreach ($token in $tokens) {
		switch -Regex ($token) {
			'^(mfa|multifactorauthentication)$' { 'MFA'; break }
			'^(justification)$' { 'Justification'; break }
			default { $token }
		}
	}

	# Sort and deduplicate, then join
	($normalized | Sort-Object -Unique) -join ','
}
