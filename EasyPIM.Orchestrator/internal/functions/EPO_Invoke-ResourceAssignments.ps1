function New-EasyPIMAssignments {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)] [object]$Config,
		[Parameter(Mandatory)] [string]$TenantId,
		[Parameter()] [string]$SubscriptionId
	)

	# Store original verbose preference to restore later
	$script:originalVerbosePreference = $VerbosePreference

	$summary = [pscustomobject]@{
		Created        = 0
		Skipped        = 0
		Failed         = 0
		PlannedCreated = 0
	}

	if (-not $Config -or -not $Config.PSObject.Properties.Name -contains 'Assignments' -or -not $Config.Assignments) {
		Write-Verbose "[Assignments] No Assignments block found; nothing to do"
		return $summary
	}

	$assign = $Config.Assignments
	$whatIf = $WhatIfPreference

	function Invoke-Safely {
		param(
			[Parameter(Mandatory)] [scriptblock]$Script,
			[string]$Context
		)
		try {
			& $Script
			Write-Host "  ✅ Assignment created: $Context" -ForegroundColor Green
			$true
		} catch {
			$emsg = $_.Exception.Message
			
			# Handle different types of errors with appropriate messages
			if ($emsg -match 'RoleAssignmentExists|The Role assignment already exists') {
				Write-Host "  ⏭️ Skipped existing: $Context" -ForegroundColor Yellow
				return $true
			}
			elseif ($emsg -match 'POLICY VALIDATION FAILED') {
				# Extract just the clear policy message, suppress ARM 400 errors
				$policyMsg = $emsg -replace '.*inner=', '' -replace 'Error, script did not terminate gracefuly \| inner=', ''
				Write-Host "  🚫 Policy conflict: $Context" -ForegroundColor Magenta
				Write-Host "     $policyMsg" -ForegroundColor Yellow
				return $false
			}
			elseif ($emsg -match 'ARM API call failed.*400.*Bad Request' -and $emsg -match 'principalID') {
				# Suppress verbose ARM 400 errors that we know are policy-related
				Write-Host "  🚫 Assignment failed: $Context - Policy validation or parameter issue" -ForegroundColor Magenta
				return $false
			}
			else {
				# Other genuine errors
				Write-Host "  ❌ Assignment failed: $Context" -ForegroundColor Red
				Write-Host "     Error: $emsg" -ForegroundColor Yellow
				return $false
			}
		}
	}

	# Entra Roles
	if ($assign.PSObject.Properties.Name -contains 'EntraRoles' -and $assign.EntraRoles) {
		foreach ($roleBlock in $assign.EntraRoles) {
			$roleName = $roleBlock.roleName
			foreach ($a in ($roleBlock.assignments | Where-Object { $_ })) {
				$ctx = "Entra/$roleName/$($a.principalId) [$($a.assignmentType)]"
				if ($whatIf) { $summary.PlannedCreated++ ; continue }
				# Idempotency: skip if already assigned (active or eligible) for directory scope '/'
				try {
					$role = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $roleName -ErrorAction Stop
					$VerbosePreference = 'SilentlyContinue'  # Suppress confusing "0 assignments found" messages
					$existsActive = Get-PIMEntraRoleActiveAssignment -tenantID $TenantId -principalID $a.principalId -rolename $roleName -ErrorAction SilentlyContinue
					$existsElig = Get-PIMEntraRoleEligibleAssignment -tenantID $TenantId -principalID $a.principalId -rolename $roleName -ErrorAction SilentlyContinue
					$VerbosePreference = $script:originalVerbosePreference
					if ($existsActive -or $existsElig) {
						$existingType = if ($existsActive) { "Active" } else { "Eligible" }
						Write-Host "  ⏭️ Skipped existing: $ctx [Found: $existingType]" -ForegroundColor Yellow
						$summary.Skipped++
						continue
					}
				} catch { 
					$VerbosePreference = $script:originalVerbosePreference
					# Pre-check failed, but assignment will still be attempted
					Write-Verbose ("[Assignments] Entra pre-check skipped for ${ctx} (will attempt assignment anyway): {0}" -f $_.Exception.Message) 
				}
				$sb = {
					if ($a.assignmentType -match 'Active') {
						$params = @{ tenantID = $TenantId; rolename = $roleName; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMEntraRoleActiveAssignment @params | Out-Null
					} else {
						$params = @{ tenantID = $TenantId; rolename = $roleName; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMEntraRoleEligibleAssignment @params | Out-Null
					}
				}
				if (Invoke-Safely -Script $sb -Context $ctx) { $summary.Created++ } else { $summary.Failed++ }
			}
		}
	}

	# Azure Resource Roles
	if ($assign.PSObject.Properties.Name -contains 'AzureRoles' -and $assign.AzureRoles) {
		foreach ($roleBlock in $assign.AzureRoles) {
			$roleName = $roleBlock.RoleName; if (-not $roleName) { $roleName = $roleBlock.roleName }
			$scope = $roleBlock.Scope; if (-not $scope) { $scope = $roleBlock.scope }
			foreach ($a in ($roleBlock.assignments | Where-Object { $_ })) {
				$ctx = "Azure/$roleName@$scope/$($a.principalId) [$($a.assignmentType)]"
				if ($whatIf) { $summary.PlannedCreated++ ; continue }
				# Idempotency: naive check via active/eligible getters if available; otherwise proceed
				try {
					$VerbosePreference = 'SilentlyContinue'  # Suppress confusing verbose output
					$existsActive = Get-PIMAzureResourceActiveAssignment -tenantID $TenantId -subscriptionID $SubscriptionId -scope $scope -principalId $a.principalId -ErrorAction SilentlyContinue
					$existsElig = Get-PIMAzureResourceEligibleAssignment -tenantID $TenantId -subscriptionID $SubscriptionId -scope $scope -principalId $a.principalId -ErrorAction SilentlyContinue
					$VerbosePreference = $script:originalVerbosePreference
					if ($existsActive -or $existsElig) { Write-Host "  ⏭️ Skipped existing: $ctx" -ForegroundColor Yellow; $summary.Skipped++; continue }
				} catch { 
					$VerbosePreference = $script:originalVerbosePreference
					# Pre-check failed, but assignment will still be attempted
					Write-Verbose ("[Assignments] Azure pre-check skipped for ${ctx} (will attempt assignment anyway): {0}" -f $_.Exception.Message) 
				}
				$sb = {
					if ($a.assignmentType -match 'Active') {
						$params = @{ tenantID = $TenantId; subscriptionID = $SubscriptionId; scope = $scope; rolename = $roleName; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMAzureResourceActiveAssignment @params | Out-Null
					} else {
						$params = @{ tenantID = $TenantId; subscriptionID = $SubscriptionId; scope = $scope; rolename = $roleName; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMAzureResourceEligibleAssignment @params | Out-Null
					}
				}
				if (Invoke-Safely -Script $sb -Context $ctx) { $summary.Created++ } else { $summary.Failed++ }
			}
		}
	}

	# Group Roles
	if ($assign.PSObject.Properties.Name -contains 'Groups' -and $assign.Groups) {
		foreach ($grp in $assign.Groups) {
			$groupId = $grp.groupId
			$roleName = $grp.roleName
			# normalize to API expected values for group membership type (owner|member)
			$groupType = $roleName
			try { if ($roleName) { $ln = $roleName.ToLower(); if ($ln -in @('owner','member')) { $groupType = $ln } } } catch { Write-Verbose "[Assignments] Could not normalize group type '$roleName': $($_.Exception.Message)" }
			foreach ($a in ($grp.assignments | Where-Object { $_ })) {
				$ctx = "Group/$groupId/$roleName/$($a.principalId) [$($a.assignmentType)]"
				if ($whatIf) { $summary.PlannedCreated++ ; continue }
				# Idempotency: check existing elig/active for group PIM
				try {
					$VerbosePreference = 'SilentlyContinue'  # Suppress confusing verbose output
					$existsActive = Get-PIMGroupActiveAssignment -tenantID $TenantId -groupID $groupId -principalID $a.principalId -type $groupType -ErrorAction SilentlyContinue
					$existsElig = Get-PIMGroupEligibleAssignment -tenantID $TenantId -groupID $groupId -principalID $a.principalId -type $groupType -ErrorAction SilentlyContinue
					$VerbosePreference = $script:originalVerbosePreference
					if ($existsActive -or $existsElig) { Write-Host "  ⏭️ Skipped existing: $ctx" -ForegroundColor Yellow; $summary.Skipped++; continue }
				} catch { 
					$VerbosePreference = $script:originalVerbosePreference
					# Pre-check failed, but assignment will still be attempted
					Write-Verbose ("[Assignments] Group pre-check skipped for ${ctx} (will attempt assignment anyway): {0}" -f $_.Exception.Message) 
				}
				$sb = {
					if ($a.assignmentType -match 'Active') {
						$params = @{ tenantID = $TenantId; groupID = $groupId; type = $groupType; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMGroupActiveAssignment @params | Out-Null
					} else {
						$params = @{ tenantID = $TenantId; groupID = $groupId; type = $groupType; principalID = $a.principalId }
						if ($a.duration)   { $params.duration = $a.duration }
						if ($a.permanent)  { $params.permanent = $true }
						if ($a.justification) { $params.justification = $a.justification }
						New-PIMGroupEligibleAssignment @params | Out-Null
					}
				}
				if (Invoke-Safely -Script $sb -Context $ctx) { $summary.Created++ } else { $summary.Failed++ }
			}
		}
	}

	return $summary
}
