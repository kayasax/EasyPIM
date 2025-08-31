function Get-ResolvedPolicyObject {
	<#
	.SYNOPSIS
	Extracts the resolved policy from a policy object.

	.DESCRIPTION
	Checks if a policy object has a ResolvedPolicy property and returns it,
	otherwise returns the original object. Used for template-resolved policies.

	.PARAMETER Policy
	The policy object to resolve.

	.OUTPUTS
	Object. The resolved policy object or the original policy.

	.EXAMPLE
	$resolved = Get-ResolvedPolicyObject -Policy $policyWithTemplate
	#>
	[CmdletBinding()]
	param([Parameter(Mandatory)][object]$Policy)

	if ($Policy.PSObject.Properties['ResolvedPolicy'] -and $Policy.ResolvedPolicy) {
		return $Policy.ResolvedPolicy
	}
	return $Policy
}
