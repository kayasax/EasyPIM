function Test-GroupEligibleForPIM {
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$GroupId
	)
	try {
		$graphEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -Verbose:$false
		$uri = "$graphEndpoint/v1.0/groups/$GroupId`?`$select=id,displayName,onPremisesSyncEnabled,groupTypes"
		$groupDetails = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
		if ($groupDetails.onPremisesSyncEnabled -eq $true) {
			Write-Warning "Group $($groupDetails.displayName) ($GroupId) is synchronized from on-premises and cannot be managed by PIM"
			return $false
		}
		if ($groupDetails.groupTypes -and $groupDetails.groupTypes -contains "Unified") {
			Write-Verbose "Group $($groupDetails.displayName) ($GroupId) is a Microsoft 365 group"
		}
		return $true
	}
	catch {
		Write-Warning "Error checking group $GroupId eligibility for PIM: $_"
		return $false
	}
}
