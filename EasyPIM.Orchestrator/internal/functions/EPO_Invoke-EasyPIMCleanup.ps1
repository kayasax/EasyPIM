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
		$results = [pscustomobject]@{ Kept=0; Removed=0; Skipped=0; Protected=0; WouldRemoveCount=0 }
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
		return $results
	}

	# Orchestrator-only, non-destructive cleanup summary (no cross-module calls)
	$results = [pscustomobject]@{ Kept=0; Removed=0; Skipped=0; Protected=0; WouldRemoveCount=0 }

	# Only analyze in delta mode; initial mode is intentionally a no-op without explicit rules
	if ($Mode -eq 'delta' -and $Config -and $Config.PSObject.Properties.Name -contains 'Assignments' -and $Config.Assignments) {
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

		Write-Verbose "[Cleanup] Orchestrator analysis complete. Desired entries=$($desired.Keys.Count). No removals executed."
	}

	return $results
}
