function Initialize-EasyPIMAssignments {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[object]$Config
	)
	# Prefer the core module implementation when available
	$coreImpl = Get-Command -Name Initialize-EasyPIMAssignments -Module EasyPIM -ErrorAction SilentlyContinue
	if ($coreImpl) {
		return & $coreImpl @PSBoundParameters
	}
	# Minimal pass-through: ensure expected properties exist to avoid null refs downstream
	$out = $Config | ConvertTo-Json -Depth 100 | ConvertFrom-Json
	foreach ($name in 'AzureRoles','AzureRolesActive','EntraIDRoles','EntraIDRolesActive','GroupRoles','GroupRolesActive','Assignments') {
		if (-not $out.PSObject.Properties[$name]) { $out | Add-Member -MemberType NoteProperty -Name $name -Value @() }
		elseif ($null -eq $out.$name) { $out.$name = @() }
	}
	return $out
}

