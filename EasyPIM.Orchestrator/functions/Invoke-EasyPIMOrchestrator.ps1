<#
.SYNOPSIS
Invokes the EasyPIM end-to-end orchestration (policies, cleanup, assignments) with safety validation.
.DESCRIPTION
Loads a configuration (file or Key Vault secret), validates principals, (optionally) applies/validates role & group policies,
performs cleanup (initial full reconcile or delta additive mode), and provisions assignments. Designed for progressive
adoption using -WhatIf previews and an explicit destructive 'initial' mode.
.PARAMETER ConfigFilePath
Path to a JSON configuration file containing ProtectedUsers, PolicyTemplates, role policies, and Assignments blocks.
.PARAMETER KeyVaultName
Name of Azure Key Vault containing a secret that stores the JSON configuration (alternative to ConfigFilePath).
.PARAMETER SecretName
Name of the Key Vault secret that holds the JSON configuration.
.PARAMETER TenantId
Target Entra (Azure AD) tenant GUID. If omitted, attempts to use $env:tenantid.
.PARAMETER SubscriptionId
Target Azure subscription GUID for Azure Resource role policy/assignment operations. If omitted, attempts $env:subscriptionid.
.PARAMETER Mode
Assignment cleanup mode: 'delta' (add/update only) or 'initial' (destructive reconcile removing undeclared assignments, except ProtectedUsers).
.PARAMETER Operations
Filter which assignment domains (AzureRoles, EntraRoles, GroupRoles) to process. Default 'All'.
.PARAMETER PolicyOperations
Filter which policy domains to process. Default 'All'.
.PARAMETER SkipAssignments
Skip the assignment creation phase (useful for policy-only validation or cleanup-only scenarios).
.PARAMETER SkipCleanup
Skip cleanup (no removal / WouldRemove evaluation). Assignments still created if not skipped.
.PARAMETER SkipPolicies
Skip policy processing; existing policies are left untouched.
.PARAMETER WouldRemoveExportPath
Directory OR file path to export the full list of assignments that WOULD be removed during a -WhatIf run (or that WERE removed in a non -WhatIf initial run).
Behavior:
	* If a directory is supplied, a timestamped file 'EasyPIM-WouldRemove-<UTC>.json' is created.
	* If a file path is supplied without extension, '.json' is appended.
	* If the extension is '.csv', a CSV file (headers: PrincipalId,PrincipalName,RoleName,Scope,ResourceType,Mode) is produced; otherwise JSON.
	* File is ALWAYS written even under -WhatIf to provide a tangible audit artifact (empty list => empty JSON array or header-only CSV).
Use cases: change review, audit evidence, diffing consecutive previews, verifying ProtectedUsers coverage before destructive apply.
.PARAMETER AllowProtectedRoles
Allow policy changes to protected roles (Entra: Global Administrator, Privileged Role Administrator, Security Administrator, User Access Administrator; Azure: Owner, User Access Administrator).
WARNING: This bypasses critical security safeguards. Policy changes to these roles will be logged and require explicit confirmation.
Use with extreme caution and only with proper authorization and change management processes.
.EXAMPLE
Invoke-EasyPIMOrchestrator -ConfigFilePath .\pim-config.json -TenantId $env:tenantid -SubscriptionId $env:subscriptionid -Mode initial -WhatIf -WouldRemoveExportPath .\LOGS
Produces a preview (no changes) and writes a timestamped JSON file under .\LOGS listing every assignment that would be removed by an initial reconcile.
.EXAMPLE
Invoke-EasyPIMOrchestrator -ConfigFilePath .\pim-config.json -TenantId <tenant> -SubscriptionId <sub> -Mode initial -WhatIf -WouldRemoveExportPath .\preview.csv
Same preview, but exports CSV (because extension is .csv) suitable for Excel review / sign-off.
.EXAMPLE
Invoke-EasyPIMOrchestrator -ConfigFilePath .\pim-config.json -TenantId <tenant> -SubscriptionId <sub> -AllowProtectedRoles -WhatIf
Preview policy changes including protected roles (Global Administrator, Owner, etc.). Requires explicit confirmation when applied without -WhatIf.
WARNING: Only use -AllowProtectedRoles with proper authorization and change management approval.
.NOTES
Always run destructive 'initial' mode with -WhatIf first; inspect summary and export file, adjust ProtectedUsers, then re-run without -WhatIf.
.LINK
https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator
#>
function Invoke-EasyPIMOrchestrator {
	[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact='Medium')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPositionalParameters", "", Justification="All public cmdlets use named parameters; any remaining triggers are false positives or internal methods.")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Top-level ShouldProcess invoked; inner creation functions also use ShouldProcess")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="False positive previously; pattern implemented below")]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
		[string]$KeyVaultName,
		[Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
		[string]$SecretName,
		[Parameter(Mandatory = $false)]
		[string]$SubscriptionId,
		[Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
		[string]$ConfigFilePath,
		[Parameter(Mandatory = $false)]
		[ValidateSet("initial", "delta")]
		[string]$Mode = "delta",
		[Parameter(Mandatory = $false)]
		[string]$TenantId,
		[Parameter(Mandatory = $false)]
		[ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
		[string[]]$Operations = @("All"),
		[Parameter(Mandatory = $false)]
		[switch]$SkipAssignments,
		[Parameter(Mandatory = $false)]
		[switch]$SkipCleanup,
		[Parameter(Mandatory = $false)]
		[switch]$SkipPolicies,
		[Parameter(Mandatory = $false)]
	[ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
	[string[]]$PolicyOperations = @("All"),
		[Parameter(Mandatory = $false)]
		[string]$WouldRemoveExportPath,
		[Parameter(Mandatory = $false)]
		[switch]$AllowProtectedRoles
	)
	# Non-gating ShouldProcess: still emits WhatIf message but always executes body for rich simulation output.
	$null = $PSCmdlet.ShouldProcess("EasyPIM Orchestration lifecycle", "Execute")
	# Normalize mode casing for internal logic (accepts initial/delta in any case)
	$Mode = $Mode.ToLowerInvariant()
	Write-SectionHeader -Message "Starting EasyPIM Orchestration (Mode: $Mode)"
	# Display usage if no parameters are provided
	if (-not $PSBoundParameters) {
		Show-EasyPIMUsage
		return
	}
	# Check Microsoft Graph authentication before proceeding
	try {
		$mgContext = Get-MgContext -ErrorAction SilentlyContinue
		if (-not $mgContext) {
			Write-Host "🔐 [AUTH] Microsoft Graph authentication required for EasyPIM operations." -ForegroundColor Yellow
			Write-Host "🔐 [AUTH] Please connect to Microsoft Graph with appropriate scopes:" -ForegroundColor Yellow
			Write-Host "  Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory'" -ForegroundColor Green
			throw "Microsoft Graph authentication required. Please run Connect-MgGraph first."
		}

		# For federated credentials, Account may be null but ClientId should be present
		$authIdentifier = $mgContext.Account ?? $mgContext.ClientId ?? "Service Principal"

		# Check if we have required Graph scopes
		$requiredScopes = @('RoleManagement.ReadWrite.Directory')
		$currentScopes = $mgContext.Scopes
		if (-not $currentScopes -or ($requiredScopes | Where-Object { $_ -notin $currentScopes })) {
			Write-Host "⚠️ [AUTH] Insufficient Microsoft Graph permissions detected." -ForegroundColor Yellow
			Write-Host "🔐 [AUTH] Please reconnect with required scopes:" -ForegroundColor Yellow
			Write-Host "  Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory'" -ForegroundColor Green
			throw "Microsoft Graph requires RoleManagement.ReadWrite.Directory scope."
		}
		Write-Host "✅ [AUTH] Microsoft Graph connection verified (Identity: $authIdentifier)" -ForegroundColor Green

		# Check Azure PowerShell authentication with OIDC support
		$azContext = Get-AzContext -ErrorAction SilentlyContinue
		$hasAzureAuth = $false
		$azureAuthMethod = "Unknown"

		# Check for Azure PowerShell context
		if ($azContext) {
			$hasAzureAuth = $true
			$azureAuthMethod = "Azure PowerShell Context"
			$accountInfo = $azContext.Account ?? $azContext.Account.Id ?? "Service Principal"
			Write-Host "✅ [AUTH] Azure PowerShell connection verified (Account: $accountInfo, Subscription: $($azContext.Subscription.Name))" -ForegroundColor Green
		}
		# Check for OIDC environment variables as fallback
		elseif ($env:AZURE_ACCESS_TOKEN -or ($env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID)) {
			$hasAzureAuth = $true
			$azureAuthMethod = "OIDC Environment Variables"
			Write-Host "✅ [AUTH] OIDC authentication detected via environment variables" -ForegroundColor Green
			if ($env:AZURE_CLIENT_ID) {
				Write-Host "  Client ID: $($env:AZURE_CLIENT_ID)" -ForegroundColor Gray
			}
			if ($env:AZURE_TENANT_ID) {
				Write-Host "  Tenant ID: $($env:AZURE_TENANT_ID)" -ForegroundColor Gray
			}
		}

		if (-not $hasAzureAuth) {
			Write-Host ""
			Write-Host "❌ [ERROR] No Azure authentication found!" -ForegroundColor Red
			Write-Host "🔐 [AUTH] Please provide Azure authentication via one of these methods:" -ForegroundColor Yellow
			Write-Host ""
			Write-Host "Option 1 - Azure PowerShell (Interactive):" -ForegroundColor Cyan
			if ($TenantId) {
				Write-Host "  Connect-AzAccount -TenantId '$TenantId'" -ForegroundColor Green
			} else {
				Write-Host "  Connect-AzAccount" -ForegroundColor Green
				Write-Host "  # Or specify tenant: Connect-AzAccount -TenantId 'your-tenant-id'" -ForegroundColor Gray
			}
			Write-Host ""
			Write-Host "Option 2 - OIDC/CI-CD Environment Variables:" -ForegroundColor Cyan
			Write-Host "  Set AZURE_ACCESS_TOKEN=<arm-api-token>" -ForegroundColor Green
			Write-Host "  Or set AZURE_CLIENT_ID and AZURE_TENANT_ID for service principal" -ForegroundColor Green
			Write-Host ""
			throw "Azure authentication required. Please authenticate using one of the methods above."
		}
	} catch {
		Write-Error "Authentication check failed: $($_.Exception.Message)"
		return
	}
	try {
		# Initialize telemetry for this execution
		$telemetryStartTime = Get-Date
		$sessionId = [System.Guid]::NewGuid().ToString()

		# 1. Load configuration
		$config = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
			Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
		} else {
			Get-EasyPIMConfiguration -ConfigFilePath $ConfigFilePath
		}

		# Check telemetry consent on first run (only for file-based configs)
		if ($PSCmdlet.ParameterSetName -ne 'KeyVault') {
			Test-TelemetryConfiguration -ConfigPath $ConfigFilePath
		}

		# Send startup telemetry (non-blocking)
		$startupProperties = @{
			"execution_mode" = if ($WhatIfPreference) { "WhatIf" } else { $Mode }
			"protected_roles_override" = $AllowProtectedRoles.IsPresent
			"config_source" = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') { "KeyVault" } else { "File" }
			"skip_assignments" = $SkipAssignments.IsPresent
			"skip_cleanup" = $SkipCleanup.IsPresent
			"skip_policies" = $SkipPolicies.IsPresent
			"session_id" = $sessionId
		}
		# Send startup telemetry (non-blocking)
		try {
			if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
				# For KeyVault configs, pass the loaded config object directly
				Send-TelemetryEventFromConfig -EventName "orchestrator_startup" -Properties $startupProperties -Config $loadedConfig
			} else {
				# For file-based configs, use the file path
				Send-TelemetryEvent -EventName "orchestrator_startup" -Properties $startupProperties -ConfigPath $ConfigFilePath
			}
		} catch {
			Write-Verbose "Telemetry startup failed (non-blocking): $($_.Exception.Message)"
		}
		# Session rule: prefer environment variables for TenantId / SubscriptionId when not explicitly supplied
		if (-not $TenantId -or [string]::IsNullOrWhiteSpace($TenantId)) {
			$TenantId = $env:tenantid
			if ($TenantId) { Write-Host -Object "ℹ️ [INFO] Using TenantId from environment: $TenantId" -ForegroundColor DarkCyan } else { Write-Host -Object "⚠️ [WARN] TenantId not provided and TENANTID env var is empty." -ForegroundColor Yellow }
		}
		# Propagate tenant/subscription to shared helpers
		try {
			$script:tenantID = $TenantId
			Set-Variable -Scope Global -Name tenantID -Value $TenantId -Force
		} catch {
			Write-Warning "Failed to set tenant ID variables: $($_.Exception.Message)"
		}
		# Initialize subscription context EARLY for downstream helpers (Invoke-ARM, get-config)
		if (-not $SubscriptionId -or [string]::IsNullOrWhiteSpace($SubscriptionId)) {
			$SubscriptionId = $env:subscriptionid
			if (-not $SubscriptionId) {
				try {
					$azCtx = Get-AzContext -ErrorAction SilentlyContinue
					if ($azCtx -and $azCtx.Subscription -and $azCtx.Subscription.Id) { $SubscriptionId = $azCtx.Subscription.Id }
				} catch {
					Write-Debug "Could not retrieve Azure context for subscription ID"
				}
			}
			if ($SubscriptionId) { Write-Verbose ("[Orchestrator] Resolved SubscriptionId early: {0}" -f $SubscriptionId) }
			else { Write-Verbose "[Orchestrator] No SubscriptionId resolved yet (will continue; callers also pass explicit IDs)" }
		}
		try {
			if ($SubscriptionId) {
				$script:subscriptionID = $SubscriptionId
				Set-Variable -Scope Global -Name subscriptionID -Value $SubscriptionId -Force
			}
		} catch {
			Write-Warning "Failed to set subscription ID variables: $($_.Exception.Message)"
		}
		# 2. Process and normalize config based on selected operations
		$processedConfig = Initialize-EasyPIMAssignments -Config $config
		# 2.1. Process policy configurations if present
		$policyConfig = $null
		# If user constrained Operations but did not explicitly set PolicyOperations, mirror the Operations filter for policies
		if (-not $PSBoundParameters.ContainsKey('PolicyOperations') -and $PSBoundParameters.ContainsKey('Operations') -and ($Operations -notcontains 'All')) {
			$PolicyOperations = $Operations
		}
		if (-not $SkipPolicies -and (
			($config.PSObject.Properties['AzureRolePolicies'] -and $config.AzureRolePolicies) -or
			($config.PSObject.Properties['EntraRolePolicies'] -and $config.EntraRolePolicies) -or
			($config.PSObject.Properties['GroupPolicies'] -and $config.GroupPolicies) -or
			($config.PSObject.Properties['PolicyTemplates'] -and $config.PolicyTemplates) -or
			($config.PSObject.Properties['Policies'] -and $config.Policies) -or
			($config.PSObject.Properties['EntraRoles'] -and $config.EntraRoles.PSObject.Properties['Policies'] -and $config.EntraRoles.Policies) -or
			($config.PSObject.Properties['AzureRoles'] -and $config.AzureRoles.PSObject.Properties['Policies'] -and $config.AzureRoles.Policies) -or
			($config.PSObject.Properties['GroupRoles'] -and $config.GroupRoles.PSObject.Properties['Policies'] -and $config.GroupRoles.Policies)
		)) {
			Write-Host -Object "⚙️ [PROC] Processing policy configurations..." -ForegroundColor Cyan
			$policyConfig = Initialize-EasyPIMPolicies -Config $config -PolicyOperations $PolicyOperations -AllowProtectedRoles:$AllowProtectedRoles
			# Filter policy config based on selected policy operations
			if ($PolicyOperations -notcontains "All") {
				$filteredPolicyConfig = @{}
				foreach ($op in $PolicyOperations) {
					switch ($op) {
						"AzureRoles" {
							if ($policyConfig.ContainsKey('AzureRolePolicies')) {
								$filteredPolicyConfig.AzureRolePolicies = $policyConfig.AzureRolePolicies
							}
						}
						"EntraRoles" {
							if ($policyConfig.ContainsKey('EntraRolePolicies')) {
								$filteredPolicyConfig.EntraRolePolicies = $policyConfig.EntraRolePolicies
							}
						}
						"GroupRoles" {
							if ($policyConfig.ContainsKey('GroupPolicies')) {
								$filteredPolicyConfig.GroupPolicies = $policyConfig.GroupPolicies
							}
						}
					}
				}
				# Make filtered policy config the active policy config for policy processing
				$policyConfig = $filteredPolicyConfig
				# Merge filtered policy config with processed assignment config (for visibility)
				foreach ($key in $filteredPolicyConfig.Keys) {
					if ($processedConfig.PSObject.Properties[$key]) {
						$processedConfig.PSObject.Properties[$key].Value = $filteredPolicyConfig[$key]
					} else {
						$processedConfig | Add-Member -MemberType NoteProperty -Name $key -Value $filteredPolicyConfig[$key]
					}
				}
			} else {
				# Merge all policy config with processed config
				foreach ($key in $policyConfig.Keys) {
					if ($key -match ".*Policies$") {
						if ($processedConfig.PSObject.Properties[$key]) {
							$processedConfig.PSObject.Properties[$key].Value = $policyConfig[$key]
						} else {
							$processedConfig | Add-Member -MemberType NoteProperty -Name $key -Value $policyConfig[$key]
						}
					}
				}
			}
		} elseif ($SkipPolicies) {
			Write-Host -Object "⏭️ [WARN] Skipping policy processing as requested by SkipPolicies parameter" -ForegroundColor Yellow
		}
		# Filter config based on selected operations
		if ($Operations -notcontains "All") {
			$filteredConfig = @{}
			# Always preserve ProtectedUsers when filtering
			if ($processedConfig.PSObject.Properties.Name -contains 'ProtectedUsers') {
				$filteredConfig.ProtectedUsers = $processedConfig.ProtectedUsers
			}
			# Filter the Assignments block based on selected operations
			if ($processedConfig.PSObject.Properties.Name -contains 'Assignments') {
				$filteredAssignments = [PSCustomObject]@{}
				Write-Verbose "[Filter Debug] Original Assignments sections: $($processedConfig.Assignments.PSObject.Properties.Name -join ', ')"
				foreach ($op in $Operations) {
					Write-Verbose "[Filter Debug] Processing operation: $op"
					switch ($op) {
						"AzureRoles" {
							if ($processedConfig.Assignments.PSObject.Properties.Name -contains 'AzureRoles') {
								$filteredAssignments | Add-Member -NotePropertyName 'AzureRoles' -NotePropertyValue $processedConfig.Assignments.AzureRoles
								Write-Verbose "[Filter Debug] Added AzureRoles to filtered assignments"
							}
						}
						"EntraRoles" {
							if ($processedConfig.Assignments.PSObject.Properties.Name -contains 'EntraRoles') {
								$filteredAssignments | Add-Member -NotePropertyName 'EntraRoles' -NotePropertyValue $processedConfig.Assignments.EntraRoles
								Write-Verbose "[Filter Debug] Added EntraRoles to filtered assignments"
							}
						}
						"GroupRoles" {
							if ($processedConfig.Assignments.PSObject.Properties.Name -contains 'Groups') {
								$filteredAssignments | Add-Member -NotePropertyName 'Groups' -NotePropertyValue $processedConfig.Assignments.Groups
								Write-Verbose "[Filter Debug] Added Groups to filtered assignments"
							}
							if ($processedConfig.Assignments.PSObject.Properties.Name -contains 'GroupRoles') {
								$filteredAssignments | Add-Member -NotePropertyName 'GroupRoles' -NotePropertyValue $processedConfig.Assignments.GroupRoles
								Write-Verbose "[Filter Debug] Added GroupRoles to filtered assignments"
							}
						}
					}
				}
				Write-Verbose "[Filter Debug] Filtered Assignments sections: $($filteredAssignments.PSObject.Properties.Name -join ', ')"
				if ($filteredAssignments.PSObject.Properties.Name.Count -gt 0) {
					$filteredConfig.Assignments = $filteredAssignments
					Write-Verbose "[Filter Debug] Assignments block preserved with $($filteredAssignments.PSObject.Properties.Name.Count) sections"
				} else {
					Write-Verbose "[Filter Debug] No matching assignment sections found, Assignments block will be empty"
				}
			}
			foreach ($op in $Operations) {
				switch ($op) {
					"AzureRoles" {
						$filteredConfig.AzureRoles = $processedConfig.AzureRoles
						$filteredConfig.AzureRolesActive = $processedConfig.AzureRolesActive
					}
					"EntraRoles" {
						$filteredConfig.EntraIDRoles = $processedConfig.EntraIDRoles
						$filteredConfig.EntraIDRolesActive = $processedConfig.EntraIDRolesActive
					}
					"GroupRoles" {
						$filteredConfig.GroupRoles = $processedConfig.GroupRoles
						$filteredConfig.GroupRolesActive = $processedConfig.GroupRolesActive
					}
				}
			}
			$processedConfig = $filteredConfig
		}
	# Always perform principal & group validation before any policy or assignment operations
		Write-Host -Object "🔍 [TEST] Validating principal and group IDs..." -ForegroundColor Cyan
		$principalIds = New-Object -TypeName "System.Collections.Generic.HashSet[string]"
		Write-Verbose ("[Orchestrator] TenantId in context before validation: {0}" -f ($TenantId))
		try {
			$tpeCmd = Get-Command Test-PrincipalExists -ErrorAction SilentlyContinue
			if($tpeCmd){
				Write-Host ("[Debug] Using Test-PrincipalExists from: {0} ({1})" -f $tpeCmd.Source,$tpeCmd.Path) -ForegroundColor DarkGray
			} else {
				Write-Host "[Debug] Test-PrincipalExists not found in scope" -ForegroundColor Yellow
			}
		} catch {
			Write-Debug "Failed to check Test-PrincipalExists command availability"
		}
	$policyApproverRefs = @()
		if ($processedConfig.PSObject.Properties.Name -contains 'Assignments' -and $processedConfig.Assignments) {
			$assign = $processedConfig.Assignments
			foreach ($section in 'EntraRoles','AzureRoles','Groups') {
				if ($assign.PSObject.Properties.Name -contains $section -and $assign.$section) {
					foreach ($roleBlock in $assign.$section) {
						if ($roleBlock.PSObject.Properties.Name -contains 'assignments') {
							foreach ($a in $roleBlock.assignments) { if ($a.principalId) { [void]$principalIds.Add($a.principalId) } }
						}
						if ($section -eq 'Groups' -and $roleBlock.groupId) { [void]$principalIds.Add($roleBlock.groupId) }
					}
				}
			}
		}
		foreach ($legacySection in 'EntraIDRoles','EntraIDRolesActive','AzureRoles','AzureRolesActive','GroupRoles','GroupRolesActive') {
			if ($processedConfig.PSObject.Properties.Name -contains $legacySection -and $processedConfig.$legacySection) {
				foreach ($item in $processedConfig.$legacySection) {
					if ($item.PrincipalId) { [void]$principalIds.Add($item.PrincipalId) }
					if ($item.GroupId) { [void]$principalIds.Add($item.GroupId) }
				}
			}
		}
		# Include approver IDs from policy configurations for validation
		$approverRefsFound = 0
		$hasEntraPolicies = $false
		if ($policyConfig -and (
			($policyConfig -is [hashtable] -and $policyConfig.ContainsKey('EntraRolePolicies') -and $policyConfig.EntraRolePolicies) -or
			($policyConfig -isnot [hashtable] -and $policyConfig.PSObject.Properties['EntraRolePolicies'] -and $policyConfig.EntraRolePolicies)
		)) {
			$hasEntraPolicies = $true
			foreach ($pol in $policyConfig.EntraRolePolicies) {
				$roleNameRef = $pol.RoleName
				# Prefer ResolvedPolicy (new path), else Policy (legacy), else the object itself
				$policyRef = $null
				if ($pol.PSObject.Properties['ResolvedPolicy'] -and $pol.ResolvedPolicy) { $policyRef = $pol.ResolvedPolicy }
				elseif ($pol.PSObject.Properties['Policy'] -and $pol.Policy) { $policyRef = $pol.Policy }
				else { $policyRef = $pol }
				# Extract approvers regardless of type (hashtable vs. PSCustomObject)
				$approvers = $null
				if ($policyRef -is [hashtable]) { if ($policyRef.ContainsKey('Approvers')) { $approvers = $policyRef['Approvers'] } }
				elseif ($policyRef -and $policyRef.PSObject.Properties['Approvers']) { $approvers = $policyRef.Approvers }
				if ($approvers) {
					foreach ($ap in $approvers) {
			$apId = $null
			if ($ap -is [string]) { $apId = $ap }
			else { $apId = $ap.Id; if (-not $apId) { $apId = $ap.id } }
						if ($apId) {
							[void]$principalIds.Add([string]$apId)
							$policyApproverRefs += [pscustomobject]@{ PrincipalId = [string]$apId; RoleName = $roleNameRef }
							$approverRefsFound++
						}
					}
				}
			}
			Write-Verbose -Message ("[Orchestrator] Collected {0} approver references ({1} unique) from policyConfig.EntraRolePolicies" -f $approverRefsFound, $policyApproverRefs.Count)
		}
		# Fallback: if not found via policyConfig, inspect processedConfig attachment for visibility
		if (-not $hasEntraPolicies -or $approverRefsFound -eq 0) {
			if ($processedConfig.PSObject.Properties['EntraRolePolicies'] -and $processedConfig.EntraRolePolicies) {
				foreach ($pol in $processedConfig.EntraRolePolicies) {
					$roleNameRef = $pol.RoleName
					$policyRef = $null
					if ($pol.PSObject.Properties['ResolvedPolicy'] -and $pol.ResolvedPolicy) { $policyRef = $pol.ResolvedPolicy }
					elseif ($pol.PSObject.Properties['Policy'] -and $pol.Policy) { $policyRef = $pol.Policy }
					else { $policyRef = $pol }
					$approvers = $null
					if ($policyRef -is [hashtable]) { if ($policyRef.ContainsKey('Approvers')) { $approvers = $policyRef['Approvers'] } }
					elseif ($policyRef -and $policyRef.PSObject.Properties['Approvers']) { $approvers = $policyRef.Approvers }
					if ($approvers) {
						foreach ($ap in $approvers) {
							$apId = $null
							if ($ap -is [string]) { $apId = $ap }
							else { $apId = $ap.Id; if (-not $apId) { $apId = $ap.id } }
							if ($apId) {
								[void]$principalIds.Add([string]$apId)
								$policyApproverRefs += [pscustomobject]@{ PrincipalId = [string]$apId; RoleName = $roleNameRef }
								$approverRefsFound++
							}
						}
					}
				}
				Write-Verbose -Message ("[Orchestrator] Collected {0} approver references ({1} unique) from processedConfig.EntraRolePolicies" -f $approverRefsFound, $policyApproverRefs.Count)
			}
		}
		$validationResults = @()
		foreach ($principalIdIter in $principalIds) {
			Write-Verbose ("[Debug] Checking principal: {0}" -f $principalIdIter)
			$exists = Test-PrincipalExists -PrincipalId $principalIdIter
			$type = $null; $displayName = $null
			if ($exists) {
				# Reuse cached object if available
				if ($script:principalObjectCache -and $script:principalObjectCache.ContainsKey($principalIdIter)) {
					$obj = $script:principalObjectCache[$principalIdIter]
				} else {
						try { $obj = invoke-graph -Endpoint "directoryObjects/$principalIdIter" -ErrorAction Stop } catch {
							Write-Verbose -Message "Suppressed directory object fetch failure for ${principalIdIter}: $($_.Exception.Message)"
						}
				}
				if ($obj -and $obj.'@odata.type') { $type = $obj.'@odata.type' }
				if ($type -eq '#microsoft.graph.group') {
					$doLookup = $false
					if ($VerbosePreference) { $doLookup = $true }
					elseif ($env:EASYPIM_VERBOSE_PRINCIPAL) { $doLookup = $true }
					if ($doLookup) {
						try {
							$g = Get-MgGroup -GroupId $principalIdIter -Property Id,DisplayName -ErrorAction SilentlyContinue
							if ($g) { $displayName = $g.DisplayName }
						} catch { Write-Verbose -Message "Suppressed group lookup failure for ${principalIdIter}: $($_.Exception.Message)" }
					}
				}
			}
			$validationResults += [pscustomobject]@{ PrincipalId = $principalIdIter; Exists = $exists; Type = $type; DisplayName = $displayName }
		}
	$missing = $validationResults | Where-Object -FilterScript { -not $_.Exists }
		if ($missing.Count -gt 0) {
			Write-Host -Object "⚠️ [WARN] Principal validation failed:" -ForegroundColor Yellow
			foreach ($m in $missing) {
				$refRoles = ($policyApproverRefs | Where-Object -FilterScript { $_.PrincipalId -eq $m.PrincipalId } | Select-Object -ExpandProperty RoleName -Unique)
				if ($refRoles) {
					Write-Host -Object "   - $($m.PrincipalId): DOES NOT EXIST (referenced as Approver for Entra role(s): $([string]::Join(', ', $refRoles)))" -ForegroundColor Red
				} else {
					Write-Host -Object "   - $($m.PrincipalId): DOES NOT EXIST" -ForegroundColor Red
				}
			}
			if ($WhatIfPreference) {
				Write-Host -Object "Proceeding due to -WhatIf (preview) to allow cleanup delta visibility. These principals will be ignored." -ForegroundColor Yellow
			} else {
				Write-Host -Object "Aborting before any policy or assignment processing. Fix these IDs or run with -WhatIf to preview." -ForegroundColor Red
				return
			}
		} else {
			$checked = $validationResults.Count
			Write-Host -Object "✅ [OK] Principal validation passed ($checked principals checked, 0 missing)" -ForegroundColor Green
		}
		# Debug: show processed assignment counts (eligible/active) before policy & cleanup phases
		try {
			$dbgAzureElig = ($processedConfig.AzureRoles    | Measure-Object).Count
			$dbgAzureAct  = ($processedConfig.AzureRolesActive | Measure-Object).Count
			$dbgEntraElig = ($processedConfig.EntraIDRoles  | Measure-Object).Count
			$dbgEntraAct  = ($processedConfig.EntraIDRolesActive | Measure-Object).Count
			$dbgGroupElig = ($processedConfig.GroupRoles    | Measure-Object).Count
			$dbgGroupAct  = ($processedConfig.GroupRolesActive | Measure-Object).Count
			Write-Host -Object "[Orchestrator Debug] Assignment counts -> Azure(E:$dbgAzureElig A:$dbgAzureAct) Entra(E:$dbgEntraElig A:$dbgEntraAct) Groups(E:$dbgGroupElig A:$dbgGroupAct)" -ForegroundColor DarkCyan
		} catch { Write-Host -Object "[Orchestrator Debug] Failed to compute assignment debug counts: $($_.Exception.Message)" -ForegroundColor DarkYellow }
		# Re-affirm subscription context later as well, but avoid noisy logs
		if (-not $SubscriptionId -or [string]::IsNullOrWhiteSpace($SubscriptionId)) {
			$SubscriptionId = $env:subscriptionid
			if ($SubscriptionId) { Write-Host -Object "ℹ️ [INFO] Using SubscriptionId from environment: $SubscriptionId" -ForegroundColor DarkCyan } else { Write-Host -Object "⚠️ [WARN] SubscriptionId not provided and SUBSCRIPTIONID env var is empty (Azure role operations may be limited)." -ForegroundColor Yellow }
		}
		try {
			if ($SubscriptionId) {
				$script:subscriptionID = $SubscriptionId
				Set-Variable -Scope Global -Name subscriptionID -Value $SubscriptionId -Force
			}
		} catch {
			Write-Warning "Failed to set subscription ID variables (second attempt): $($_.Exception.Message)"
		}
		# 3. Process policies FIRST (skip if requested) - CRITICAL: Policies must be applied before assignments to ensure compliance
		$policyResults = $null
		if (-not $SkipPolicies -and $policyConfig -and (
			($policyConfig.ContainsKey('AzureRolePolicies') -and $policyConfig.AzureRolePolicies) -or
			($policyConfig.ContainsKey('EntraRolePolicies') -and $policyConfig.EntraRolePolicies) -or
			($policyConfig.ContainsKey('GroupPolicies') -and $policyConfig.GroupPolicies)
		)) {
			# Policy functions no longer support a separate 'validate' mode. Always use 'delta'; rely on -WhatIf for preview.
			$effectivePolicyMode = "delta"
			# Protected roles safety check: identify and confirm if protected roles are being modified
			if ($AllowProtectedRoles -and -not $WhatIfPreference) {
				$protectedEntraRoles = @("Global Administrator","Privileged Role Administrator","Security Administrator","User Access Administrator")
				$protectedAzureRoles = @("Owner","User Access Administrator")
				$protectedRolesFound = @()
				# Check for protected Entra roles
				if ($policyConfig.ContainsKey('EntraRolePolicies') -and $policyConfig.EntraRolePolicies) {
					$protectedEntraFound = $policyConfig.EntraRolePolicies | Where-Object { $protectedEntraRoles -contains $_.RoleName } | ForEach-Object { "Entra: $($_.RoleName)" }
					if ($protectedEntraFound) { $protectedRolesFound += $protectedEntraFound }
				}
				# Check for protected Azure roles
				if ($policyConfig.ContainsKey('AzureRolePolicies') -and $policyConfig.AzureRolePolicies) {
					$protectedAzureFound = $policyConfig.AzureRolePolicies | Where-Object { $protectedAzureRoles -contains $_.RoleName } | ForEach-Object { "Azure: $($_.RoleName)" }
					if ($protectedAzureFound) { $protectedRolesFound += $protectedAzureFound }
				}
				if ($protectedRolesFound.Count -gt 0) {
					Write-Host ""
					Write-Host "⚠️  SECURITY WARNING: Protected Role Policy Changes Detected" -ForegroundColor Red
					Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
					Write-Host "The following CRITICAL roles will have their policies modified:" -ForegroundColor Yellow
					$protectedRolesFound | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }
					Write-Host ""
					Write-Host "These changes could affect:" -ForegroundColor Yellow
					Write-Host "  • Break-glass access procedures" -ForegroundColor White
					Write-Host "  • Emergency administrative capabilities" -ForegroundColor White
					Write-Host "  • Critical security role configurations" -ForegroundColor White
					Write-Host ""
					Write-Host "This action will be logged for audit purposes." -ForegroundColor Cyan
					Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
					$confirmation = Read-Host "Type 'CONFIRM-PROTECTED-OVERRIDE' to proceed"
					if ($confirmation -ne 'CONFIRM-PROTECTED-OVERRIDE') {
						throw "Protected role policy modification cancelled by user. Run without -AllowProtectedRoles to skip protected roles."
					}
					Write-Host "🔒 [SECURITY] User confirmed protected role policy override - proceeding with changes" -ForegroundColor Green
				}
			}
			# Convert hashtable to PSCustomObject for the policy function
			$policyConfigObject = [PSCustomObject]$policyConfig
			$policyResults = New-EPOEasyPIMPolicy -Config $policyConfigObject -TenantId $TenantId -SubscriptionId $SubscriptionId -PolicyMode $effectivePolicyMode -AllowProtectedRoles:$AllowProtectedRoles -WhatIf:$WhatIfPreference
			if ($WhatIfPreference) {
				Write-Host -Object "✅ [OK] Policy dry-run completed (-WhatIf) - role policies appear correctly configured for assignment compliance" -ForegroundColor Green
			} else {
				$failed = 0; $succeeded = 0
				try {
					if ($policyResults -and $policyResults.Summary) {
						$failed = [int]$policyResults.Summary.Failed
						$succeeded = [int]$policyResults.Summary.Successful
					}
				} catch {
					Write-Verbose -Message ("[Orchestrator] Unable to read policy summary counts: {0}" -f $_.Exception.Message)
				}
				if ($failed -gt 0) {
					Write-Host -Object "⚠️ [WARN] Policy configuration completed with errors (Successful: $succeeded, Failed: $failed). Proceeding with assignments." -ForegroundColor Yellow
				} else {
					Write-Host -Object "✅ [OK] Policy configuration completed - proceeding with assignments using updated role policies" -ForegroundColor Green
				}
			}
		} elseif ($SkipPolicies) {
			Write-Warning -Message "Policy processing skipped - assignments may not comply with intended role policies"
		}
		# 4. Perform cleanup operations AFTER policy processing (skip if requested or if assignments are skipped)
		$cleanupResults = if ($Operations -contains "All" -and -not $SkipCleanup -and -not $SkipAssignments) {
			Write-Host -Object "🧹 [CLEANUP] Analyzing existing assignments against configuration..." -ForegroundColor Cyan
			$cleanupResult = Invoke-EasyPIMCleanup -Config $processedConfig -Mode $Mode -TenantId $TenantId -SubscriptionId $SubscriptionId -WouldRemoveExportPath $WouldRemoveExportPath
			if ($cleanupResult -and $cleanupResult.PSObject.Properties.Name -contains 'AnalysisCompleted' -and $cleanupResult.AnalysisCompleted) {
				Write-Host -Object "📊 [CLEANUP] Analysis complete. Found $($cleanupResult.DesiredAssignments) desired assignments." -ForegroundColor Cyan
				if ($Mode -eq 'delta') {
					Write-Host -Object "🔄 [CLEANUP] Delta mode: No assignments will be removed (add/update only)." -ForegroundColor DarkGray
				}
			}
			$cleanupResult
		} else {
			if ($SkipAssignments) { Write-Host -Object "[WARN] Skipping cleanup because SkipAssignments was specified (no assignment delta expected)" -ForegroundColor Yellow }
			elseif ($SkipCleanup) { Write-Host -Object "[WARN] Skipping cleanup as requested by SkipCleanup parameter" -ForegroundColor Yellow }
			else { Write-Host -Object "[WARN] Skipping cleanup as specific operations were selected" -ForegroundColor Yellow }
			$null
		}
		# High removal warning for initial mode
		if ($cleanupResults -and $Mode -eq 'initial' -and -not $WhatIfPreference) {
			$threshold = [int]([Environment]::GetEnvironmentVariable('EASYPIM_INITIAL_REMOVAL_WARN_THRESHOLD') | ForEach-Object -Process { if ($_ -as [int]) { $_ } else { 10 } })
			$removed = if ($cleanupResults.PSObject.Properties.Name -contains 'RemovedCount') { $cleanupResults.RemovedCount } else { $cleanupResults.Removed }
			if ($removed -gt 0) {
				$color = if ($removed -ge $threshold) { 'Red' } else { 'Yellow' }
				Write-Host -Object "[WARN] Initial mode removed $removed assignments (threshold=$threshold). Verify this matches intent. Use delta mode for add/update-only runs." -ForegroundColor $color
			}
		}
		# 5. Process assignments AFTER policies are confirmed (skip if requested)
		if (-not $SkipAssignments) {
			Write-Host -Object "[ASSIGN] Creating assignments with validated role policies..." -ForegroundColor Cyan
			# New-EasyPIMAssignments does not itself expose -WhatIf; inner Invoke-ResourceAssignment handles simulation.
			$assignmentResults = New-EasyPIMAssignments -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId
			if ($assignmentResults) {
				$totalAttempted = ($assignmentResults.Created + $assignmentResults.Failed + $assignmentResults.Skipped)
				Write-Host -Object "[ASSIGN] Assignment processing complete: $totalAttempted total, $($assignmentResults.Created) created, $($assignmentResults.Failed) failed, $($assignmentResults.Skipped) skipped" -ForegroundColor Cyan
			}
			# After assignments, attempt deferred group policies if any
			if (Get-Command -Name Invoke-EPODeferredGroupPolicies -ErrorAction SilentlyContinue) {
				# Deferred group policies follow the same rule: always use 'delta' mode; -WhatIf controls preview only.
				$retryMode = 'delta'
				$deferredSummary = Invoke-EPODeferredGroupPolicies -TenantId $TenantId -Mode $retryMode -WhatIf:$WhatIfPreference
				if ($deferredSummary) {
					$script:EasyPIM_DeferredGroupPoliciesSummary = $deferredSummary
					Write-Host -Object "Deferred Group Policies Retry:" -ForegroundColor Cyan
					Write-Host -Object "  Applied: $($deferredSummary.Applied)" -ForegroundColor Cyan
					Write-Host -Object "  Skipped: $($deferredSummary.Skipped)" -ForegroundColor Cyan
					Write-Host -Object "  Failed : $($deferredSummary.Failed)" -ForegroundColor Cyan
					# Optionally attach to policyResults summary counts
					if ($policyResults -and $policyResults.Summary) {
						$policyResults.Summary.TotalProcessed += ($deferredSummary.Applied + $deferredSummary.Skipped + $deferredSummary.Failed)
						$policyResults.Summary.Successful += $deferredSummary.Applied
						$policyResults.Summary.Failed += $deferredSummary.Failed
						$policyResults.Summary.Skipped += $deferredSummary.Skipped
					}
				}
			}
		} else {
			Write-Host -Object "[WARN] Skipping assignment creation as requested" -ForegroundColor Yellow
			$assignmentResults = $null
		}
		# 6. Display summary
	# Summary no longer distinguishes 'validate' policy mode; pass 'delta' and rely on -WhatIf for preview messaging upstream
	$effectivePolicyMode = 'delta'
	Write-EasyPIMSummary -CleanupResults $cleanupResults -AssignmentResults $assignmentResults -PolicyResults $policyResults -PolicyMode $effectivePolicyMode
	Write-Host -Object "Mode semantics: delta = add/update only (no removals), initial = full reconcile (destructive)." -ForegroundColor Gray
		Write-Host -Object "=== EasyPIM orchestration completed successfully ===" -ForegroundColor Green

		# Send completion telemetry (non-blocking)
		$telemetryEndTime = Get-Date
		$executionDuration = ($telemetryEndTime - $telemetryStartTime).TotalSeconds

		$completionProperties = @{
			"execution_mode" = if ($WhatIfPreference) { "WhatIf" } else { $Mode }
			"protected_roles_override" = $AllowProtectedRoles.IsPresent
			"execution_duration_seconds" = [math]::Round($executionDuration, 2)
			"success" = $true
			"errors_encountered" = 0
			"session_id" = $sessionId
		}

		# Add result counts if available
		if ($assignmentResults) {
			$completionProperties["assignments_created"] = $assignmentResults.Created
			$completionProperties["assignments_failed"] = $assignmentResults.Failed
			$completionProperties["assignments_skipped"] = $assignmentResults.Skipped
		}
		if ($cleanupResults) {
			$removed = if ($cleanupResults.PSObject.Properties.Name -contains 'RemovedCount') { $cleanupResults.RemovedCount } else { $cleanupResults.Removed }
			$completionProperties["assignments_removed"] = $removed
		}
		if ($policyResults -and $policyResults.Summary) {
			$completionProperties["policies_processed"] = $policyResults.Summary.TotalProcessed
			$completionProperties["policies_successful"] = $policyResults.Summary.Successful
			$completionProperties["policies_failed"] = $policyResults.Summary.Failed
		}

		# Send completion telemetry (non-blocking)
		try {
			if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
				# For KeyVault configs, pass the loaded config object directly
				Send-TelemetryEventFromConfig -EventName "orchestrator_completion" -Properties $completionProperties -Config $loadedConfig
			} else {
				# For file-based configs, use the file path
				Send-TelemetryEvent -EventName "orchestrator_completion" -Properties $completionProperties -ConfigPath $ConfigFilePath
			}
		} catch {
			Write-Verbose "Telemetry completion failed (non-blocking): $($_.Exception.Message)"
		}
	}
	catch {
		# Send error telemetry (non-blocking)
		if ($sessionId) {
			$errorProperties = @{
				"execution_mode" = if ($WhatIfPreference) { "WhatIf" } else { $Mode }
				"protected_roles_override" = $AllowProtectedRoles.IsPresent
				"success" = $false
				"error_type" = $_.Exception.GetType().Name
				"session_id" = $sessionId
			}

			if ($telemetryStartTime) {
				$errorDuration = ((Get-Date) - $telemetryStartTime).TotalSeconds
				$errorProperties["execution_duration_seconds"] = [math]::Round($errorDuration, 2)
			}

			try {
				if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
					# For KeyVault configs, pass the loaded config object directly
					Send-TelemetryEventFromConfig -EventName "orchestrator_error" -Properties $errorProperties -Config $loadedConfig
				} else {
					# For file-based configs, use the file path
					Send-TelemetryEvent -EventName "orchestrator_error" -Properties $errorProperties -ConfigPath $ConfigFilePath
				}
			} catch {
				Write-Verbose "Telemetry error failed (non-blocking): $($_.Exception.Message)"
			}
		}

	Write-Error -Message "[ERROR] An error occurred: $($_.Exception.Message)"
		Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
		throw
	}
}
