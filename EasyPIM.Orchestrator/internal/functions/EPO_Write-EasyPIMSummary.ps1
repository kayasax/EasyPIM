function Write-EasyPIMSummary {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
	param (
		[Parameter()]
		[PSCustomObject]$CleanupResults,

		[Parameter()]
		[PSCustomObject]$AssignmentResults,

		[Parameter()]
		[hashtable]$PolicyResults,

		[Parameter()]
		[string]$PolicyMode = "delta"
	)

	Write-Host "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" -ForegroundColor Green
	Write-Host "┃ OVERALL SUMMARY                                                                ┃" -ForegroundColor Green
	Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" -ForegroundColor Green

	Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
	Write-Host "| ASSIGNMENT CREATIONS" -ForegroundColor White
	Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

	if ($null -ne $AssignmentResults) {
		$planned = if ($AssignmentResults.PSObject.Properties.Name -contains 'PlannedCreated') { $AssignmentResults.PlannedCreated } else { $null }
		Write-Host "| [OK] Created : $($AssignmentResults.Created)" -ForegroundColor White
		if ($null -ne $planned) {
			Write-Host "| [PLAN] Planned : $planned" -ForegroundColor White
		}
		Write-Host "| [SKIP] Skipped : $($AssignmentResults.Skipped)" -ForegroundColor White
		Write-Host "| [FAIL] Failed  : $($AssignmentResults.Failed)" -ForegroundColor White
	} else {
		Write-Host "| [OK] Created : 0" -ForegroundColor White
		Write-Host "| [SKIP] Skipped : 0" -ForegroundColor White
		Write-Host "| [FAIL] Failed  : 0" -ForegroundColor White
	}
	Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White

	Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
	Write-Host "| POLICY OPERATIONS" -ForegroundColor White
	Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

	if ($null -ne $PolicyResults -and $null -ne $PolicyResults.Summary) {
		Write-Host "| [OK] Applied : $($PolicyResults.Summary.Successful)" -ForegroundColor White
		Write-Host "| [SKIP] Skipped : $($PolicyResults.Summary.Skipped)" -ForegroundColor White
		Write-Host "| [FAIL] Failed  : $($PolicyResults.Summary.Failed)" -ForegroundColor White
		Write-Host "| [INFO] Total   : $($PolicyResults.Summary.TotalProcessed)" -ForegroundColor White
	} else {
		Write-Host "| [OK] Applied : 0" -ForegroundColor White
		Write-Host "| [SKIP] Skipped : 0" -ForegroundColor White
		Write-Host "| [FAIL] Failed  : 0" -ForegroundColor White
		Write-Host "| [INFO] Total   : 0" -ForegroundColor White
	}
	Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White

	Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
	Write-Host "| CLEANUP OPERATIONS" -ForegroundColor White
	Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

	if ($null -ne $CleanupResults) {
		$kept = if ($null -ne $CleanupResults.KeptCount) { $CleanupResults.KeptCount }
				elseif ($null -ne $CleanupResults.Kept) { $CleanupResults.Kept }
				else { 0 }

		$removed = if ($null -ne $CleanupResults.RemovedCount) { $CleanupResults.RemovedCount }
				elseif ($null -ne $CleanupResults.Removed) { $CleanupResults.Removed }
				else { 0 }

		$skipped = if ($null -ne $CleanupResults.SkippedCount) { $CleanupResults.SkippedCount }
				elseif ($null -ne $CleanupResults.Skipped) { $CleanupResults.Skipped }
				else { 0 }

		$protected = if ($null -ne $CleanupResults.ProtectedCount) { $CleanupResults.ProtectedCount }
				elseif ($null -ne $CleanupResults.Protected) { $CleanupResults.Protected }
				else { 0 }

		Write-Host "| [OK] Kept    : $kept" -ForegroundColor White
		Write-Host "| [DEL] Removed : $removed" -ForegroundColor White
		if ($CleanupResults.PSObject.Properties.Name -contains 'WouldRemoveCount') {
			Write-Host "| [INFO] WouldRemove: $($CleanupResults.WouldRemoveCount)" -ForegroundColor White
			if ($CleanupResults.PSObject.Properties.Name -contains 'WouldRemoveDetails' -and $CleanupResults.WouldRemoveDetails -and $CleanupResults.WouldRemoveDetails.Count -gt 0) {
				$previewSample = $CleanupResults.WouldRemoveDetails | Select-Object -First 5
				foreach($item in $previewSample){
					$sc = if ($item.Scope) { $item.Scope } else { '' }
					Write-Host "|    - $($item.RoleName) $sc $($item.PrincipalId)" -ForegroundColor DarkGray
				}
				if ($CleanupResults.WouldRemoveDetails.Count -gt 5) {
					Write-Host "|    ... (+$($CleanupResults.WouldRemoveDetails.Count - 5) more)" -ForegroundColor DarkGray
				}
			}
			if ($CleanupResults.PSObject.Properties.Name -contains 'WouldRemoveExportPath' -and $CleanupResults.WouldRemoveExportPath) {
				Write-Host "|    Export file: $($CleanupResults.WouldRemoveExportPath)" -ForegroundColor DarkGray
			}
		}
		Write-Host "| [SKIP] Skipped : $skipped" -ForegroundColor White
		if ($protected -gt 0) {
			Write-Host "| 🛡️ Protected: $protected" -ForegroundColor White
		}
	} else {
		Write-Host "| [OK] Kept    : 0" -ForegroundColor White
		Write-Host "| [DEL] Removed : 0" -ForegroundColor White
		Write-Host "| [SKIP] Skipped : 0" -ForegroundColor White
	}
	Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White

	if ($script:EasyPIM_DeferredGroupPoliciesSummary) {
		$dg = $script:EasyPIM_DeferredGroupPoliciesSummary
		Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
		Write-Host "| DEFERRED GROUP POLICIES" -ForegroundColor White
		Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White
		Write-Host "| [OK] Applied           : $($dg.Applied)" -ForegroundColor White
		Write-Host "| ⏳ Still Not Eligible: $($dg.StillNotEligible)" -ForegroundColor White
		Write-Host "| [FAIL] Failed            : $($dg.Failed)" -ForegroundColor White
		Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
	}
}
