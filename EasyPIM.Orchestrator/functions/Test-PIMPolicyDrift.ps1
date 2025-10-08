<#
.SYNOPSIS
Tests PIM role assignment policy configuration for drift against live settings.

.DESCRIPTION
Reads a policy configuration JSON file (with optional templates), resolves the expected
settings for Entra roles, Azure resource roles, and group roles, and compares them with
the live PIM policies in the specified tenant. Reports matches, drift, and errors.
Optionally throws when drift is detected.

.PARAMETER TenantId
The Entra tenant ID to query for PIM policy settings.
<#
.SYNOPSIS
Tests PIM role assignment policy configuration for drift against live settings.

.DESCRIPTION
Reads a policy configuration JSON file (with optional templates), or loads the config from Azure Key Vault, resolves the expected
settings for Entra roles, Azure resource roles, and group roles, and compares them with

Optionally throws when drift is detected.

.PARAMETER TenantId
The Entra tenant ID to query for PIM policy settings.

.PARAMETER ConfigPath
Path to the JSON configuration file describing expected PIM policies. Supports line
comments (//) and block comments (/* */) which will be removed before parsing. Optional if using KeyVaultName/SecretName.

.PARAMETER KeyVaultName
Name of the Azure Key Vault to load the configuration from. Optional. If specified, must also provide SecretName.

.PARAMETER SecretName
Name of the secret in Azure Key Vault containing the base64-encoded JSON configuration. Optional. If specified, must also provide KeyVaultName.

.PARAMETER SubscriptionId
Optional Azure subscription ID. Required if the config includes Azure resource role
policies to validate.

.PARAMETER FailOnDrift
If set, throws an error when any policy drift or error is detected.

.PARAMETER PassThru
If set, suppresses formatted console output and is intended for use in pipelines.
Note: The function always returns the results array; PassThru only affects host output.

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
PSCustomObject. One object per evaluated policy with properties:
Type, Name, Target, Status (Match|Drift|Error|SkippedRoleNotFound), Differences.

.EXAMPLE
Test-PIMPolicyDrift -TenantId 00000000-0000-0000-0000-000000000000 -ConfigPath .\examples\scripts\pim-policies.json

Compares Entra and group role policies from the config to live settings in the tenant.

.EXAMPLE
Test-PIMPolicyDrift -TenantId 00000000-0000-0000-0000-000000000000 -ConfigPath .\config\pim.json -SubscriptionId 11111111-1111-1111-1111-111111111111 -FailOnDrift -Verbose

Validates Entra, group, and Azure resource role policies and throws if drift is found.

.EXAMPLE
Test-PIMPolicyDrift -TenantId $env:TenantId -ConfigPath .\config\pim.json -PassThru | Where-Object Status -ne 'Match'

Returns only the items where drift or error is present.

.EXAMPLE
Test-PIMPolicyDrift -TenantId 00000000-0000-0000-0000-000000000000 -KeyVaultName 'MyVault' -SecretName 'PIMConfigSecret'

Loads the configuration from Azure Key Vault secret 'PIMConfigSecret' in vault 'MyVault' (must be base64-encoded JSON), and compares policies to live settings.

.NOTES
Module: EasyPIM.Orchestrator (requires EasyPIM core module)
Author: Kayasax and contributors
License: MIT (same as EasyPIM)

Authentication Context and MFA Requirements:
Microsoft Entra PIM automatically removes MultiFactorAuthentication requirements when
Authentication Context is enabled to prevent MfaAndAcrsConflict. This is expected
behavior and will not be flagged as drift by this function.

.LINK
https://github.com/kayasax/EasyPIM
#>
function Test-PIMPolicyDrift {
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPositionalParameters", "", Justification="Parameters are named at call sites; internal helper calls may trigger false positives.")]
	param(
		[Parameter(Mandatory)][string]$TenantId,
		[Parameter()][string]$ConfigPath,
		[string]$KeyVaultName,
		[string]$SecretName,
		[string]$SubscriptionId,
		[switch]$FailOnDrift,
		[switch]$PassThru
	)

	Write-Verbose -Message "Starting PIM policy drift test. ConfigPath: $ConfigPath, KeyVaultName: $KeyVaultName, SecretName: $SecretName"

	# Initialize telemetry for this execution
	$telemetryStartTime = Get-Date
	$sessionId = [System.Guid]::NewGuid().ToString()

	try {
		# Load config using enhanced error handling
		if ($KeyVaultName -and $SecretName) {
			Write-Verbose "Loading config from Azure Key Vault using enhanced error handling: $KeyVaultName, secret: $SecretName"
			try {
				# Use the enhanced Get-EasyPIMConfiguration with retry logic
				$json = Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
				$configRaw = $json | ConvertTo-Json -Depth 100 # For logging purposes
			} catch {
				Write-Error "Failed to load config from Key Vault with enhanced error handling: $($_.Exception.Message)"
				throw
			}
		} elseif ($ConfigPath) {
			try {
				$ConfigPath = (Resolve-Path -Path $ConfigPath -ErrorAction Stop).Path
				# Use enhanced file loading too
				$json = Get-EasyPIMConfiguration -ConfigFilePath $ConfigPath
				$configRaw = Get-Content -Raw -Path $ConfigPath # For logging purposes
			} catch {
				throw "Failed to load config file: $($_.Exception.Message)"
			}
		} else {
			throw "You must specify either -ConfigPath or both -KeyVaultName and -SecretName."
		}
		if (-not $json) { throw "Parsed JSON object is null - invalid configuration." }

		# Send startup telemetry (non-blocking)
		$startupProperties = @{
			"function" = "Test-PIMPolicyDrift"
			"config_source" = if ($KeyVaultName -and $SecretName) { "KeyVault" } else { "File" }
			"fail_on_drift" = $FailOnDrift.IsPresent
			"pass_thru" = $PassThru.IsPresent
			"has_subscription_id" = (-not [string]::IsNullOrEmpty($SubscriptionId))
			"session_id" = $sessionId
		}
		try {
			if ($KeyVaultName -and $SecretName) {
				# For KeyVault configs, pass the loaded config object directly
				Send-TelemetryEventFromConfig -EventName "drift_test_startup" -Properties $startupProperties -Config $json
			} else {
				# For file-based configs, use the file path
				Send-TelemetryEvent -EventName "drift_test_startup" -Properties $startupProperties -ConfigPath $ConfigPath
			}
		} catch {
			Write-Verbose "Telemetry startup failed (non-blocking): $($_.Exception.Message)"
		}

	# Initialize collections for expected policies
	$expectedAzure = @()
	$expectedEntra = @()
	$expectedGroup = @()
	$templates = @{}

	# Extract templates if present
	if ($json.PSObject.Properties['PolicyTemplates']) {
		foreach ($templateName in ($json.PolicyTemplates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
			$templates[$templateName] = $json.PolicyTemplates.$templateName
		}
	}

	# 🆕 Use the same policy processing logic as the orchestrator for consistency
	try {
		$processedConfig = Initialize-EasyPIMPolicies -Config $json -PolicyTemplates $templates
		$expectedEntra = $processedConfig.EntraRolePolicies | ForEach-Object {
			$resolvedPolicy = if ($_.PSObject.Properties['ResolvedPolicy']) { $_.ResolvedPolicy } else { $_.Policy }
			[pscustomobject]@{ RoleName = $_.RoleName; ResolvedPolicy = $resolvedPolicy }
		}
		$expectedAzure = $processedConfig.AzureRolePolicies | ForEach-Object {
			$resolvedPolicy = if ($_.PSObject.Properties['ResolvedPolicy']) { $_.ResolvedPolicy } else { $_.Policy }
			[pscustomobject]@{ RoleName = $_.RoleName; Scope = $_.Scope; ResolvedPolicy = $resolvedPolicy }
		}
		$expectedGroup = $processedConfig.GroupPolicies | ForEach-Object {
			$resolvedPolicy = if ($_.PSObject.Properties['ResolvedPolicy']) { $_.ResolvedPolicy } else { $_.Policy }
			[pscustomobject]@{ GroupId = $_.GroupId; GroupName = $_.GroupName; RoleName = $_.RoleName; ResolvedPolicy = $resolvedPolicy }
		}
	} catch {
		Write-Warning "Failed to use orchestrator policy processing, falling back to local logic: $_"

	# Fallback to original logic - process different configuration formats
	if ($json.PSObject.Properties['AzureRolePolicies']) { $expectedAzure += $json.AzureRolePolicies }
	if ($json.PSObject.Properties['EntraRolePolicies']) {
		if ($json.EntraRolePolicies -is [System.Collections.IEnumerable] -and $json.EntraRolePolicies -isnot [string]) {
			foreach ($entry in $json.EntraRolePolicies) {
				if ($entry -and $entry.PSObject.Properties['RoleName']) {
					$expectedEntra += $entry
				}
			}
		} else {
			$expectedEntra += $json.EntraRolePolicies
		}
	}
	if ($json.PSObject.Properties['GroupPolicies']) {
		if ($json.GroupPolicies -is [System.Collections.IEnumerable] -and $json.GroupPolicies -isnot [string]) {
			foreach ($entry in $json.GroupPolicies) {
				if ($entry -and ($entry.PSObject.Properties['GroupId'] -or $entry.PSObject.Properties['GroupName'])) {
					$expectedGroup += $entry
				}
			}
		} else {
			$expectedGroup += $json.GroupPolicies
		}
	}

	# Process nested format configurations
	if ($json.PSObject.Properties['AzureRoles'] -and $json.AzureRoles.PSObject.Properties['Policies']) {
		foreach ($prop in $json.AzureRoles.Policies.PSObject.Properties) {
			$roleName = $prop.Name
			$policy = $prop.Value
			if (-not $policy) { continue }

			$obj = [pscustomobject]@{ RoleName = $roleName; Scope = $policy.Scope }
			foreach ($policyProperty in $policy.PSObject.Properties) {
				if ($policyProperty.Name -notin @('Scope')) {
					$obj | Add-Member -NotePropertyName $policyProperty.Name -NotePropertyValue $policyProperty.Value -Force
				}
			}
			$expectedAzure += $obj
		}
	}

	if ($json.PSObject.Properties['EntraRoles'] -and $json.EntraRoles.PSObject.Properties['Policies']) {
		$entraPolicies = $json.EntraRoles.Policies
		if ($entraPolicies -is [System.Collections.IEnumerable] -and $entraPolicies -isnot [string]) {
			foreach ($entry in $entraPolicies) {
				if ($entry -and $entry.PSObject.Properties['RoleName']) {
					$expectedEntra += $entry
				}
			}
		} else {
			foreach ($prop in $entraPolicies.PSObject.Properties) {
				$roleName = $prop.Name
				$policy = $prop.Value
				if (-not $policy) { continue }

				$obj = [pscustomobject]@{ RoleName = $roleName }
				foreach ($policyProperty in $policy.PSObject.Properties) {
					$obj | Add-Member -NotePropertyName $policyProperty.Name -NotePropertyValue $policyProperty.Value -Force
				}
				$expectedEntra += $obj
			}
		}
	}

	if ($json.PSObject.Properties['Groups'] -and $json.Groups.PSObject.Properties['Policies']) {
		$groupPolicies = $json.Groups.Policies
		if ($groupPolicies -is [System.Collections.IEnumerable] -and $groupPolicies -isnot [string]) {
			foreach ($entry in $groupPolicies) {
				if ($entry -and ($entry.PSObject.Properties['GroupId'] -or $entry.PSObject.Properties['GroupName']) -and $entry.PSObject.Properties['RoleName']) {
					$expectedGroup += $entry
				}
			}
		} else {
			foreach ($groupProperty in $groupPolicies.PSObject.Properties) {
				$groupId = $groupProperty.Name
				$roleBlock = $groupProperty.Value
				if (-not $roleBlock) { continue }

				foreach ($roleProperty in $roleBlock.PSObject.Properties) {
					$roleName = $roleProperty.Name
					$policy = $roleProperty.Value
					if (-not $policy) { continue }

					$obj = [pscustomobject]@{ GroupId = $groupId; RoleName = $roleName }
					foreach ($policyProperty in $policy.PSObject.Properties) {
						$obj | Add-Member -NotePropertyName $policyProperty.Name -NotePropertyValue $policyProperty.Value -Force
					}
					$expectedGroup += $obj
				}
			}
		}
	}

	if ($json.PSObject.Properties['GroupRoles'] -and $json.GroupRoles.PSObject.Properties['Policies']) {
		foreach ($groupProperty in $json.GroupRoles.Policies.PSObject.Properties) {
			$groupId = $groupProperty.Name
			$roleBlock = $groupProperty.Value
			if (-not $roleBlock) { continue }

			foreach ($roleProperty in $roleBlock.PSObject.Properties) {
				$roleName = $roleProperty.Name
				$policy = $roleProperty.Value
				if (-not $policy) { continue }

				$obj = [pscustomobject]@{ GroupId = $groupId; RoleName = $roleName }
				foreach ($policyProperty in $policy.PSObject.Properties) {
					$obj | Add-Member -NotePropertyName $policyProperty.Name -NotePropertyValue $policyProperty.Value -Force
				}
				$expectedGroup += $obj
			}
		}
	}

		# Apply template resolution for fallback processing
		$expectedAzure = $expectedAzure | ForEach-Object -Process {
			$_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-PolicyTemplate -Object $_ -Templates $templates) -Force
			$_
		}
		$expectedEntra = $expectedEntra | ForEach-Object -Process {
			$_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-PolicyTemplate -Object $_ -Templates $templates) -Force
			$_
		}
		$expectedGroup = $expectedGroup | ForEach-Object -Process {
			$_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-PolicyTemplate -Object $_ -Templates $templates) -Force
			$_
		}
	}

	# Initialize tracking variables
	$results = @()
	$driftCount = 0

	# Display processing summary
	$totalPolicies = $expectedAzure.Count + $expectedEntra.Count + $expectedGroup.Count
	if ($totalPolicies -gt 0) {
		Write-Host "🔍 Processing $totalPolicies policies..." -ForegroundColor Cyan
		if ($expectedAzure.Count -gt 0) { Write-Host "   • Azure Resource roles: $($expectedAzure.Count)" -ForegroundColor Gray }
		if ($expectedEntra.Count -gt 0) { Write-Host "   • Entra roles: $($expectedEntra.Count)" -ForegroundColor Gray }
		if ($expectedGroup.Count -gt 0) { Write-Host "   • Group roles: $($expectedGroup.Count)" -ForegroundColor Gray }
	}

	# Process Azure role policies
	if ($expectedAzure.Count -gt 0 -and -not $SubscriptionId) {
		Write-Warning -Message "Azure role policies present but no -SubscriptionId provided; skipping Azure role validation."
	} elseif ($expectedAzure.Count -gt 0) {
		Write-Host "📋 Testing Azure Resource role policies..." -ForegroundColor DarkCyan
		foreach ($policy in $expectedAzure) {
			$resolvedPolicy = Get-ResolvedPolicyObject -Policy $policy

			if (-not $policy.Scope) {
				$results += [pscustomobject]@{
					Type = 'AzureRole'
					Name = $policy.RoleName
					Target = '(missing scope)'
					Status = 'Error'
					Differences = 'Missing Scope'
				}
				$driftCount++
				continue
			}

			try {
				# 🔧 SCOPE FIX: Use the policy's specific scope instead of subscription-level only
				if ($policy.Scope -and $policy.Scope -ne "/subscriptions/$SubscriptionId") {
					# Use scope-based query for resource-level policies
					Write-Verbose "Drift detection: Using resource scope '$($policy.Scope)' for role '$($policy.RoleName)'"
					$live = Get-PIMAzureResourcePolicy -tenantID $TenantId -scope $policy.Scope -rolename $policy.RoleName -ErrorAction Stop
				} else {
					# Use subscription-based query for subscription-level policies
					Write-Verbose "Drift detection: Using subscription scope for role '$($policy.RoleName)'"
					$live = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $policy.RoleName -ErrorAction Stop
				}
				if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) {
					$live = @($live)[0]
				}

				$approverCount = if ($resolvedPolicy.Approvers) { $resolvedPolicy.Approvers.Count } else { $null }
				Compare-PIMPolicy -Type 'AzureRole' -Name $policy.RoleName -Expected $resolvedPolicy -Live $live -ExtraId $policy.Scope -ApproverCountExpected $approverCount -Results ([ref]$results) -DriftCount ([ref]$driftCount)
			} catch {
				$results += [pscustomobject]@{
					Type = 'AzureRole'
					Name = $policy.RoleName
					Target = $policy.Scope
					Status = 'Error'
					Differences = $_.Exception.Message
				}
				$driftCount++
			}
		}
	}

	# Process Entra role policies
	if ($expectedEntra.Count -gt 0) {
		Write-Host "🏢 Testing Entra role policies..." -ForegroundColor DarkCyan
	}
	foreach ($policy in $expectedEntra) {
		if ($policy._RoleNotFound) {
			$results += [pscustomobject]@{
				Type = 'EntraRole'
				Name = $policy.RoleName
				Target = '/'
				Status = 'SkippedRoleNotFound'
				Differences = ''
			}
			continue
		}

		$resolvedPolicy = Get-ResolvedPolicyObject -Policy $policy

		try {
			$live = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $policy.RoleName -ErrorAction Stop
			if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) {
				$live = @($live)[0]
			}
			if (-not $live) { throw "Live policy returned null for role '$($policy.RoleName)'" }

			$approverCount = if ($resolvedPolicy.Approvers) { $resolvedPolicy.Approvers.Count } else { $null }
			Compare-PIMPolicy -Type 'EntraRole' -Name $policy.RoleName -Expected $resolvedPolicy -Live $live -ApproverCountExpected $approverCount -Results ([ref]$results) -DriftCount ([ref]$driftCount)
		} catch {
			$results += [pscustomobject]@{
				Type = 'EntraRole'
				Name = $policy.RoleName
				Target = '/'
				Status = 'Error'
				Differences = $_.Exception.Message
			}
			$driftCount++
		}
	}

	# Process Group role policies
	if ($expectedGroup.Count -gt 0) {
		Write-Host "👥 Testing Group role policies..." -ForegroundColor DarkCyan
	}
	foreach ($policy in $expectedGroup) {
		$resolvedPolicy = Get-ResolvedPolicyObject -Policy $policy

		# Handle legacy property names
		if (-not $resolvedPolicy.PSObject.Properties['ActivationRequirement'] -and $resolvedPolicy.PSObject.Properties['EnablementRules'] -and $resolvedPolicy.EnablementRules) {
			try { $resolvedPolicy | Add-Member -NotePropertyName ActivationRequirement -NotePropertyValue $resolvedPolicy.EnablementRules -Force } catch { $resolvedPolicy.ActivationRequirement = $resolvedPolicy.EnablementRules }
		}
		if (-not $resolvedPolicy.PSObject.Properties['ActivationDuration'] -and $resolvedPolicy.PSObject.Properties['Duration'] -and $resolvedPolicy.Duration) {
			try { $resolvedPolicy | Add-Member -NotePropertyName ActivationDuration -NotePropertyValue $resolvedPolicy.Duration -Force } catch { $resolvedPolicy.ActivationDuration = $resolvedPolicy.Duration }
		}

		# Resolve group ID from name if needed
		if (-not $policy.GroupId -and $policy.GroupName) {
			try {
				$endpoint = "groups?`$filter=displayName eq '$($policy.GroupName.Replace("'","''"))'"
				$response = invoke-graph -Endpoint $endpoint
				if ($response.value -and $response.value.Count -gt 0) {
					$policy | Add-Member -NotePropertyName GroupId -NotePropertyValue $response.value[0].id -Force
				}
			} catch {
				Write-Warning -Message "Group resolution failed for '$($policy.GroupName)': $($_.Exception.Message)"
			}
		}

		$groupId = $policy.GroupId
		if (-not $groupId) {
			$targetGroupRef = if ($policy.GroupName) { $policy.GroupName } else { '(unknown)' }
			$results += [pscustomobject]@{
				Type = 'Group'
				Name = $policy.RoleName
				Target = $targetGroupRef
				Status = 'Error'
				Differences = 'Missing GroupId'
			}
			$driftCount++
			continue
		}

		try {
			$live = Get-PIMGroupPolicy -tenantID $TenantId -groupID $groupId -type ($policy.RoleName.ToLower()) -ErrorAction Stop
			if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) {
				$live = @($live)[0]
			}

			$approverCount = if ($resolvedPolicy.Approvers) { $resolvedPolicy.Approvers.Count } else { $null }
			Compare-PIMPolicy -Type 'Group' -Name $policy.RoleName -Expected $resolvedPolicy -Live $live -ExtraId $groupId -ApproverCountExpected $approverCount -Results ([ref]$results) -DriftCount ([ref]$driftCount)
		} catch {
			$results += [pscustomobject]@{
				Type = 'Group'
				Name = $policy.RoleName
				Target = $groupId
				Status = 'Error'
				Differences = $_.Exception.Message
			}
			$driftCount++
		}
	}

	# Display results unless PassThru is specified
	if (-not $PassThru) {
		Write-Host -Object "Policy Verification Results:" -ForegroundColor Cyan
		$results | Sort-Object -Property Type, Name | Format-Table -AutoSize

		$summary = $results | Group-Object -Property Status | Select-Object -Property Name, Count
		Write-Host -Object "`nSummary:" -ForegroundColor Cyan
		$summary | Format-Table -AutoSize

		if ($results.Count -eq 0) {
			Write-Host -Object "No policies discovered in config (nothing compared)." -ForegroundColor Yellow
		} else {
			$driftCount = ($results | Where-Object { $_.Status -in 'Drift', 'Error' }).Count
			if ($driftCount -eq 0) {
				Write-Host -Object "All compared policy fields match expected values." -ForegroundColor Green
			} else {
				Write-Host -Object "Drift detected in $driftCount policy item(s)." -ForegroundColor Yellow
			}
		}
	}

	# Throw if drift detected and FailOnDrift is set
	if ($FailOnDrift -and ($results | Where-Object -FilterScript { $_.Status -in 'Drift', 'Error' })) {
		throw "PIM policy drift detected."
	}

	# Send completion telemetry (non-blocking)
	$telemetryEndTime = Get-Date
	$executionDuration = ($telemetryEndTime - $telemetryStartTime).TotalSeconds

	$completionProperties = @{
		"function" = "Test-PIMPolicyDrift"
		"config_source" = if ($KeyVaultName -and $SecretName) { "KeyVault" } else { "File" }
		"execution_duration_seconds" = [math]::Round($executionDuration, 2)
		"success" = $true
		"session_id" = $sessionId
		"total_policies_tested" = $results.Count
		"policies_with_drift" = ($results | Where-Object { $_.Status -eq 'Drift' }).Count
		"policies_with_errors" = ($results | Where-Object { $_.Status -eq 'Error' }).Count
		"policies_matching" = ($results | Where-Object { $_.Status -eq 'Match' }).Count
		"policies_skipped" = ($results | Where-Object { $_.Status -eq 'SkippedRoleNotFound' }).Count
		"azure_policies_tested" = ($results | Where-Object { $_.Type -eq 'AzureRole' }).Count
		"entra_policies_tested" = ($results | Where-Object { $_.Type -eq 'EntraRole' }).Count
		"group_policies_tested" = ($results | Where-Object { $_.Type -eq 'Group' }).Count
		"has_subscription_id" = (-not [string]::IsNullOrEmpty($SubscriptionId))
		"fail_on_drift" = $FailOnDrift.IsPresent
		"pass_thru" = $PassThru.IsPresent
	}

	try {
		if ($KeyVaultName -and $SecretName) {
			# For KeyVault configs, pass the loaded config object directly
			Send-TelemetryEventFromConfig -EventName "drift_test_completion" -Properties $completionProperties -Config $json
		} else {
			# For file-based configs, use the file path
			Send-TelemetryEvent -EventName "drift_test_completion" -Properties $completionProperties -ConfigPath $ConfigPath
		}
	} catch {
		Write-Verbose "Telemetry completion failed (non-blocking): $($_.Exception.Message)"
	}

	return $results

	} catch {
		# Send error telemetry (non-blocking)
		if ($sessionId) {
			$errorProperties = @{
				"function" = "Test-PIMPolicyDrift"
				"config_source" = if ($KeyVaultName -and $SecretName) { "KeyVault" } else { "File" }
				"fail_on_drift" = $FailOnDrift.IsPresent
				"success" = $false
				"error_type" = $_.Exception.GetType().Name
				"session_id" = $sessionId
			}

			if ($telemetryStartTime) {
				$errorDuration = ((Get-Date) - $telemetryStartTime).TotalSeconds
				$errorProperties["execution_duration_seconds"] = [math]::Round($errorDuration, 2)
			}

			try {
				if ($KeyVaultName -and $SecretName) {
					# For KeyVault configs, pass the loaded config object directly
					Send-TelemetryEventFromConfig -EventName "drift_test_error" -Properties $errorProperties -Config $json
				} else {
					# For file-based configs, use the file path
					Send-TelemetryEvent -EventName "drift_test_error" -Properties $errorProperties -ConfigPath $ConfigPath
				}
			} catch {
				Write-Verbose "Telemetry error failed (non-blocking): $($_.Exception.Message)"
			}
		}

		Write-Error -Message "[ERROR] An error occurred during drift testing: $($_.Exception.Message)"
		Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
		throw
	}
}
