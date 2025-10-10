<#
.SYNOPSIS
Resolves a principal identifier (object ID, UPN, appId, or display name) to directory object metadata.

.DESCRIPTION
Provides a consistent way for EasyPIM cmdlets to translate friendly principal identifiers into Microsoft Entra object IDs.
Supports users, service principals, and groups with intelligent fallbacks and uniqueness validation.

.PARAMETER PrincipalIdentifier
The identifier to resolve. Accepts object ID, user principal name, service principal appId, or display name.

.PARAMETER PreferredTypes
Optional ordering of directory object types to probe when using display name or appId lookups.

.PARAMETER AllowDisplayNameLookup
When specified, attempts to resolve non-UPN, non-GUID identifiers using display name equality across preferred types.

.PARAMETER AllowAppIdLookup
When specified, attempts to resolve GUID input as service principal appId if direct object lookup fails.

.PARAMETER ErrorContext
Optional textual context to include in thrown errors for easier troubleshooting.

.OUTPUTS
PSCustomObject with Id, Type, DisplayName, UserPrincipalName, Mail, and Raw (original Graph payload).

.EXAMPLE
Resolve-EasyPIMPrincipal -PrincipalIdentifier "user@contoso.com"

.EXAMPLE
Resolve-EasyPIMPrincipal -PrincipalIdentifier "Contoso Automation" -AllowDisplayNameLookup

.NOTES
Author: EasyPIM Contributors
#>
function Resolve-EasyPIMPrincipal {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$PrincipalIdentifier,

		[string[]]
		$PreferredTypes = @('user', 'servicePrincipal', 'group'),

		[switch]
		$AllowDisplayNameLookup,

		[switch]
		$AllowAppIdLookup,

		[string]
		$ErrorContext
	)

	$identifier = $PrincipalIdentifier.Trim()
	if ([string]::IsNullOrWhiteSpace($identifier)) {
		throw "Principal identifier cannot be empty."
	}

	$contextMessage = if ($ErrorContext) { "[$ErrorContext] " } else { "" }

	$convertPrincipal = {
		param($item)
		if (-not $item) { return $null }

		$odataType = $item.'@odata.type'
		$type = switch -regex ($odataType) {
			'microsoft.graph.user'              { 'user'; break }
			'microsoft.graph.servicePrincipal'  { 'servicePrincipal'; break }
			'microsoft.graph.group'             { 'group'; break }
			default {
				if ($item.userPrincipalName) { 'user' }
				elseif ($item.appId) { 'servicePrincipal' }
				elseif ($item.mailNickname -and -not $item.securityEnabled) { 'group' }
				else { 'directoryObject' }
			}
		}

		return [PSCustomObject]@{
			Id                  = $item.id
			Type                = $type
			DisplayName         = $item.displayName
			UserPrincipalName   = $item.userPrincipalName
			Mail                = $item.mail
			Raw                 = $item
		}
	}

	function Get-SingleResult {
		param(
			[Parameter(Mandatory = $true)]
			$Response,
			[Parameter(Mandatory = $true)]
			[string]
			$LookupDescription
		)

		if (-not $Response) {
			return $null
		}

		$items = @()
		if ($Response.PSObject.Properties.Name -contains 'value' -and $Response.value) {
			$items = @($Response.value)
		}
		elseif ($Response.id) {
			$items = @($Response)
		}

		if ($items.Count -eq 0) {
			return $null
		}
		elseif ($items.Count -gt 1) {
			$names = $items | ForEach-Object { if ($_ -and $_.displayName) { $_.displayName } else { $_.id } }
			throw "${contextMessage}Multiple directory objects matched '$PrincipalIdentifier' during $LookupDescription lookup. Refine the identifier to be unique. Matches: $(($names -join ', '))."
		}

		return & $convertPrincipal $items[0]
	}

	$parsedGuid = [Guid]::Empty
	$isGuid = [Guid]::TryParse($identifier, [ref]$parsedGuid)

	if ($isGuid) {
		try {
			$byObjectId = invoke-graph -Endpoint "directoryObjects/$identifier"
			$result = Get-SingleResult -Response $byObjectId -LookupDescription 'objectId'
			if ($result) {
				return $result
			}
		}
		catch {
			Write-Verbose "${contextMessage}directoryObjects lookup failed for '$identifier': $($_.Exception.Message)"
		}

		if ($AllowAppIdLookup) {
			try {
				$sp = invoke-graph -Endpoint 'servicePrincipals' -Filter "appId eq '$identifier'"
				$result = Get-SingleResult -Response $sp -LookupDescription 'servicePrincipal appId'
				if ($result) {
					return $result
				}
			}
			catch {
				Write-Verbose "${contextMessage}servicePrincipal appId lookup failed for '$identifier': $($_.Exception.Message)"
			}
		}
	}

	if ($identifier -match '.+@.*\..+') {
		try {
			$byUpn = invoke-graph -Endpoint "users/$identifier"
			$result = Get-SingleResult -Response $byUpn -LookupDescription 'UPN'
			if ($result) {
				return $result
			}
		}
		catch {
			Write-Verbose "${contextMessage}User UPN lookup failed for '$identifier': $($_.Exception.Message)"
		}
	}

	if ($AllowDisplayNameLookup) {
		$escaped = $identifier.Replace("'", "''")
		foreach ($type in $PreferredTypes) {
			$endpoint = switch ($type.ToLowerInvariant()) {
				'user'             { 'users' }
				'serviceprincipal' { 'servicePrincipals' }
				'group'            { 'groups' }
				default            { $null }
			}

			if (-not $endpoint) {
				continue
			}

			try {
				$response = invoke-graph -Endpoint $endpoint -Filter "displayName eq '$escaped'"
				$result = Get-SingleResult -Response $response -LookupDescription "$type displayName"
				if ($result) {
					return $result
				}
			}
			catch {
				Write-Verbose "${contextMessage}$type displayName lookup failed for '$identifier': $($_.Exception.Message)"
			}
		}
	}

	throw "${contextMessage}Unable to resolve principal identifier '$PrincipalIdentifier'. Provide an object ID, UPN, or a unique display name."
}