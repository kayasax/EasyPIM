function Resolve-PolicyTemplate {
	<#
	.SYNOPSIS
	Resolves a policy object with template inheritance.

	.DESCRIPTION
	Applies template inheritance to a policy object by merging template
	properties with object-specific overrides. Used as fallback when
	orchestrator template processing is not available.

	.PARAMETER Object
	The policy object that may contain a Template reference.

	.PARAMETER Templates
	Hashtable of available templates indexed by name.

	.OUTPUTS
	Object. The policy object with template properties merged.

	.EXAMPLE
	$resolved = Resolve-PolicyTemplate -Object $policy -Templates $templates
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)][object]$Object,
		[Parameter(Mandatory)][hashtable]$Templates
	)

	if (-not $Object) { return $Object }

	if ($Object.Template -and $Templates.ContainsKey($Object.Template)) {
		# Create a deep copy of the template
		$baseTemplate = $Templates[$Object.Template] | ConvertTo-Json -Depth 20 | ConvertFrom-Json

		# Apply object properties as overrides
		foreach ($property in $Object.PSObject.Properties) {
			if ($property.Name -ne 'Template') {
				$baseTemplate | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
			}
		}

		return $baseTemplate
	}

	return $Object
}
