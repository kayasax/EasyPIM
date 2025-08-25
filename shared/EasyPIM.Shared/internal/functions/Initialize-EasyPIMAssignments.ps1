function Initialize-EasyPIMAssignments {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[object]$Config
	)
	# Minimal normalization to avoid null refs downstream; core module has a richer implementation
	$out = $Config | ConvertTo-Json -Depth 100 | ConvertFrom-Json
	foreach ($name in 'AzureRoles','AzureRolesActive','EntraIDRoles','EntraIDRolesActive','GroupRoles','GroupRolesActive','Assignments','ProtectedUsers') {
		if (-not $out.PSObject.Properties[$name]) { $out | Add-Member -MemberType NoteProperty -Name $name -Value @() }
		elseif ($null -eq $out.$name) { $out.$name = @() }
	}
	return $out
}
