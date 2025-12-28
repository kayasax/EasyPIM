function Invoke-EasyPIMCleanup {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [pscustomobject]$Config,
		[Parameter(Mandatory=$true)] [ValidateSet('delta','initial')] [string]$Mode,
		[Parameter(Mandatory=$false)] [string]$TenantId,
		[Parameter(Mandatory=$false)] [string]$SubscriptionId,
		[Parameter(Mandatory=$false)] [string]$WouldRemoveExportPath
	)

	Write-Verbose "[Cleanup] Starting cleanup (mode=$Mode)"
	if ($PSCmdlet.ShouldProcess('Cleanup operations', 'Invoke EasyPIM cleanup')) {
		# Orchestrator-only cleanup fallback (no dependency on core module)
		$results = [pscustomobject]@{
			Kept=0; Removed=0; Skipped=0; Protected=0; WouldRemoveCount=0
			AnalysisCompleted=$false; DesiredAssignments=0; Mode=$Mode
			CleanupStatus="Cleanup not performed"
		}
		$desired = @{}
		if ($Config.Assignments) {
			if ($Config.Assignments.EntraRoles) {
				foreach ($r in $Config.Assignments.EntraRoles) {
					foreach ($a in @($r.assignments)) { if ($a) { $key = "entra::$($r.roleName)::/::$($a.principalId)"; $desired[$key] = $true } }
				}
			}
			if ($Config.Assignments.AzureRoles) {
				foreach ($r in $Config.Assignments.AzureRoles) {
					$rn = $r.RoleName; if (-not $rn) { $rn=$r.roleName }
					$sc = $r.Scope; if (-not $sc) { $sc=$r.scope }
					foreach ($a in @($r.assignments)) { if ($a) { $key = "azure::$rn::$sc::$($a.principalId)"; $desired[$key] = $true } }
				}
			}
			if ($Config.Assignments.Groups) {
				foreach ($g in $Config.Assignments.Groups) {
					foreach ($a in @($g.assignments)) { if ($a) { $key = "group::member::$($g.groupId)::$($a.principalId)"; $desired[$key] = $true } }
				}
			}
		}
		Write-Verbose "[Cleanup] Fallback: analyzed desired set size=$($desired.Keys.Count). No removals executed."
		# Update analysis details in results for better user feedback
		$results.AnalysisCompleted = $true
		$results.DesiredAssignments = $desired.Keys.Count
		if ($Mode -eq 'delta') {
			$results.CleanupStatus = "Analyzed $($desired.Keys.Count) desired assignments. Cleanup operations require core EasyPIM module."
		} else {
			$results.CleanupStatus = "Initial mode - no cleanup analysis performed in orchestrator-only mode."
		}
		return $results
	}

	# Orchestrator-only, non-destructive cleanup summary (no cross-module calls)
	$results = [pscustomobject]@{
		Kept=0; Removed=0; Skipped=0; Protected=0; WouldRemoveCount=0
		AnalysisCompleted=$false; DesiredAssignments=0; Mode=$Mode
		CleanupStatus="Cleanup not performed"
	}

	# Analyze in both delta and initial mode
	if (($Mode -eq 'delta' -or $Mode -eq 'initial') -and $Config -and $Config.PSObject.Properties.Name -contains 'Assignments' -and $Config.Assignments) {
		$desired = @{}
		if ($Config.Assignments.EntraRoles) {
			foreach ($r in $Config.Assignments.EntraRoles) {
				foreach ($a in @($r.assignments)) { if ($a) { $key = "entra::$($r.roleName)::/::$($a.principalId)"; $desired[$key] = $true } }
			}
		}
		if ($Config.Assignments.AzureRoles) {
			foreach ($r in $Config.Assignments.AzureRoles) {
				$rn = $r.RoleName; if (-not $rn) { $rn=$r.roleName }
				$sc = $r.Scope; if (-not $sc) { $sc=$r.scope }
				foreach ($a in @($r.assignments)) { if ($a) { $key = "azure::$rn::$sc::$($a.principalId)"; $desired[$key] = $true } }
			}
		}
		if ($Config.Assignments.Groups) {
			foreach ($g in $Config.Assignments.Groups) {
				foreach ($a in @($g.assignments)) { if ($a) { $key = "group::member::$($g.groupId)::$($a.principalId)"; $desired[$key] = $true } }
			}
		}

		$results.AnalysisCompleted = $true
		$results.DesiredAssignments = $desired.Keys.Count

		if ($Mode -eq 'initial') {
			Write-Verbose "[Cleanup] Initial mode: Fetching current assignments for reconciliation..."
			$removals = @()

			# Entra
			if ($Config.Assignments.EntraRoles) {
				try {
					$entraElig = Get-PIMEntraRoleEligibleAssignment -TenantId $TenantId -ErrorAction SilentlyContinue
					if ($entraElig) {
						foreach ($a in $entraElig) {
							$key = "entra::$($a.RoleName)::/::$($a.PrincipalId)"
							if (-not $desired.ContainsKey($key)) {
								$removals += [pscustomobject]@{ Type = "Entra"; Role = $a.RoleName; Principal = $a.PrincipalId; AssignmentType = "Eligible"; Scope = "/" }
							}
						}
					}
					$entraAct = Get-PIMEntraRoleActiveAssignment -TenantId $TenantId -ErrorAction SilentlyContinue
					if ($entraAct) {
						foreach ($a in $entraAct) {
							$key = "entra::$($a.RoleName)::/::$($a.PrincipalId)"
							if (-not $desired.ContainsKey($key)) {
								$removals += [pscustomobject]@{ Type = "Entra"; Role = $a.RoleName; Principal = $a.PrincipalId; AssignmentType = "Active"; Scope = "/" }
							}
						}
					}
				} catch { Write-Warning "Failed to fetch Entra assignments for cleanup: $_" }
			}

			# Azure
			if ($Config.Assignments.AzureRoles) {
				try {
					$azureElig = Get-PIMAzureResourceEligibleAssignment -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
					if ($azureElig) {
						foreach ($a in $azureElig) {
							$key = "azure::$($a.RoleName)::$($a.Scope)::$($a.PrincipalId)"
							if (-not $desired.ContainsKey($key)) {
								$removals += [pscustomobject]@{ Type = "Azure"; Role = $a.RoleName; Principal = $a.PrincipalId; AssignmentType = "Eligible"; Scope = $a.Scope }
							}
						}
					}
					$azureAct = Get-PIMAzureResourceActiveAssignment -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
					if ($azureAct) {
						foreach ($a in $azureAct) {
							$key = "azure::$($a.RoleName)::$($a.Scope)::$($a.PrincipalId)"
							if (-not $desired.ContainsKey($key)) {
								$removals += [pscustomobject]@{ Type = "Azure"; Role = $a.RoleName; Principal = $a.PrincipalId; AssignmentType = "Active"; Scope = $a.Scope }
							}
						}
					}
				} catch { Write-Warning "Failed to fetch Azure assignments for cleanup: $_" }
			}

			# Groups
			if ($Config.Assignments.Groups) {
				foreach ($g in $Config.Assignments.Groups) {
					try {
						$grpElig = Get-PIMGroupEligibleAssignment -TenantId $TenantId -GroupId $g.GroupId -ErrorAction SilentlyContinue
						if ($grpElig) {
							foreach ($a in $grpElig) {
								$key = "group::member::$($g.GroupId)::$($a.PrincipalId)"
								if (-not $desired.ContainsKey($key)) {
									$removals += [pscustomobject]@{ Type = "Group"; Role = "Member"; Principal = $a.PrincipalId; AssignmentType = "Eligible"; Scope = $g.GroupId }
								}
							}
						}
						$grpAct = Get-PIMGroupActiveAssignment -TenantId $TenantId -GroupId $g.GroupId -ErrorAction SilentlyContinue
						if ($grpAct) {
							foreach ($a in $grpAct) {
								$key = "group::member::$($g.GroupId)::$($a.PrincipalId)"
								if (-not $desired.ContainsKey($key)) {
									$removals += [pscustomobject]@{ Type = "Group"; Role = "Member"; Principal = $a.PrincipalId; AssignmentType = "Active"; Scope = $g.GroupId }
								}
							}
						}
					} catch { Write-Warning "Failed to fetch Group assignments for cleanup (Group $($g.GroupId)): $_" }
				}
			}

			$results.WouldRemoveCount = $removals.Count
			$results.Removed = $removals

			if ($removals.Count -gt 0) {
				Write-Host "⚠️ [CLEANUP] Found $($removals.Count) assignments to remove:" -ForegroundColor Yellow
				$removals | Format-Table Type, Role, Principal, AssignmentType, Scope | Out-String | Write-Host

				if (-not $PSCmdlet.ShouldProcess("Cleanup operations", "Remove $($removals.Count) assignments")) {
					Write-Host "[INFO] Cleanup skipped (WhatIf)" -ForegroundColor Cyan
				} else {
					Write-Warning "Automatic removal is not yet fully implemented in Orchestrator-only mode. Please remove these assignments manually or use the core EasyPIM module."
				}
			} else {
				Write-Host "✅ [CLEANUP] No extra assignments found." -ForegroundColor Green
			}

			$results.CleanupStatus = "Analyzed $($desired.Keys.Count) desired assignments. Found $($removals.Count) to remove."
		} else {
			$results.CleanupStatus = "Analyzed $($desired.Keys.Count) desired assignments. Full cleanup requires core EasyPIM module."
		}
		Write-Verbose "[Cleanup] Orchestrator analysis complete. Desired entries=$($desired.Keys.Count)."
	} else {
		$results.CleanupStatus = "No assignments configured for cleanup analysis."
	}

	return $results
}
