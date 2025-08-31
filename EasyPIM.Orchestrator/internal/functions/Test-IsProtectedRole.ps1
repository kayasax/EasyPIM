function Test-IsProtectedRole {
	<#
	.SYNOPSIS
	Tests if a role is considered protected based on security best practices.

	.DESCRIPTION
	Checks if a role name matches predefined lists of protected roles for
	Entra ID or Azure resource management. Protected roles require special
	handling and monitoring.

	.PARAMETER RoleName
	The name of the role to check.

	.PARAMETER Type
	The type of role: 'EntraRole', 'AzureRole', or other.

	.OUTPUTS
	Boolean. True if the role is protected, false otherwise.

	.EXAMPLE
	$isProtected = Test-IsProtectedRole -RoleName "Global Administrator" -Type "EntraRole"
	# Returns: True

	.EXAMPLE
	$isProtected = Test-IsProtectedRole -RoleName "Owner" -Type "AzureRole"
	# Returns: True
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)][string]$RoleName,
		[Parameter(Mandatory)][string]$Type
	)

	# Protected role definitions (consistent with orchestrator logic)
	$protectedEntraRoles = @(
		"Global Administrator",
		"Privileged Role Administrator",
		"Security Administrator",
		"User Access Administrator"
	)

	$protectedAzureRoles = @(
		"Owner",
		"User Access Administrator"
	)

	switch ($Type) {
		'EntraRole' { return $protectedEntraRoles -contains $RoleName }
		'AzureRole' { return $protectedAzureRoles -contains $RoleName }
		default { return $false }
	}
}
