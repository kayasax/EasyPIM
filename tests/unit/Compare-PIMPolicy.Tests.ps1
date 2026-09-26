
BeforeAll {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    
    $orchestratorInternal = Join-Path $here "../../EasyPIM.Orchestrator/internal/functions"
    
    # Dot-source dependencies
    . "$orchestratorInternal/Convert-RequirementValue.ps1"
    . "$orchestratorInternal/Test-PIMPolicyBusinessRules.ps1"
    . "$orchestratorInternal/Test-IsProtectedRole.ps1"
    . "$orchestratorInternal/Compare-PIMPolicy.ps1"
}

Describe "Compare-PIMPolicy" {
    Context "Permanent assignment duration comparison" {
        $cases = foreach ($type in @('EntraRole', 'AzureRole', 'Group')) {
            foreach ($scenario in @(
                @{ Label = 'boolean true'; Eligibility = $true; Active = $true; LiveEligibility = 'true'; LiveActive = 'true'; Differences = @() }
                @{ Label = 'string true'; Eligibility = ' True '; Active = 'TRUE'; LiveEligibility = $true; LiveActive = $true; Differences = @() }
                @{ Label = 'boolean false'; Eligibility = $false; Active = $false; LiveEligibility = 'false'; LiveActive = 'false'; Differences = @('MaximumEligibilityDuration', 'MaximumActiveAssignmentDuration') }
                @{ Label = 'string false'; Eligibility = 'False'; Active = 'false'; LiveEligibility = $false; LiveActive = $false; Differences = @('MaximumEligibilityDuration', 'MaximumActiveAssignmentDuration') }
                @{ Label = 'permanent eligibility only'; Eligibility = $true; Active = $false; LiveEligibility = 'true'; LiveActive = 'false'; Differences = @('MaximumActiveAssignmentDuration') }
                @{ Label = 'permanent active only'; Eligibility = $false; Active = $true; LiveEligibility = 'false'; LiveActive = 'true'; Differences = @('MaximumEligibilityDuration') }
                @{ Label = 'permanent flag drift'; Eligibility = $true; Active = 'true'; LiveEligibility = 'false'; LiveActive = $false; Differences = @('AllowPermanentEligibility', 'AllowPermanentActiveAssignment') }
                @{ Label = 'absent expected flags'; OmitEligibility = $true; OmitActive = $true; LiveEligibility = 'true'; LiveActive = 'true'; Differences = @('MaximumEligibilityDuration', 'MaximumActiveAssignmentDuration') }
                @{ Label = 'absent eligibility flag'; OmitEligibility = $true; Active = $true; LiveEligibility = 'true'; LiveActive = 'true'; Differences = @('MaximumEligibilityDuration') }
                @{ Label = 'absent active flag'; Eligibility = $true; OmitActive = $true; LiveEligibility = 'true'; LiveActive = 'true'; Differences = @('MaximumActiveAssignmentDuration') }
                @{ Label = 'null flags'; Eligibility = $null; Active = $null; LiveEligibility = $false; LiveActive = $false; Differences = @('MaximumEligibilityDuration', 'MaximumActiveAssignmentDuration') }
                @{ Label = 'unrecognized flags'; Eligibility = 'unknown'; Active = 'unknown'; LiveEligibility = $false; LiveActive = $false; Differences = @('MaximumEligibilityDuration', 'MaximumActiveAssignmentDuration') }
                @{ Label = 'nonzero irrelevant durations'; Eligibility = $true; Active = $true; LiveEligibility = 'true'; LiveActive = 'true'; LiveDuration = 'P90D'; Differences = @() }
                @{ Label = 'unrelated activation drift'; Eligibility = $true; Active = $true; LiveEligibility = 'true'; LiveActive = 'true'; ActivationDrift = $true; Differences = @('ActivationDuration') }
            )) {
                @{ Type = $type; Scenario = $scenario; Label = $scenario.Label }
            }
        }

        It "Handles <Label> for <Type>" -ForEach $cases {
            $expected = [pscustomobject]@{
                MaximumEligibilityDuration = 'P365D'
                MaximumActiveAssignmentDuration = 'P365D'
                ActivationDuration = 'PT8H'
            }
            if (-not $Scenario.OmitEligibility) {
                $expected | Add-Member -NotePropertyName AllowPermanentEligibility -NotePropertyValue $Scenario.Eligibility
            }
            if (-not $Scenario.OmitActive) {
                $expected | Add-Member -NotePropertyName AllowPermanentActiveAssignment -NotePropertyValue $Scenario.Active
            }
            $liveDuration = if ($Scenario.LiveDuration) { $Scenario.LiveDuration } else { 'PT0S' }
            $live = [pscustomobject]@{
                MaximumEligibleAssignmentDuration = $liveDuration
                MaximumActiveAssignmentDuration = $liveDuration
                AllowPermanentEligibleAssignment = $Scenario.LiveEligibility
                AllowPermanentActiveAssignment = $Scenario.LiveActive
                ActivationDuration = if ($Scenario.ActivationDrift) { 'PT4H' } else { 'PT8H' }
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type $Type -Name 'TestRole' -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Count | Should -Be 1
            $results.Value.Type | Should -Be $Type
            $results.Value.DifferencesList.Count | Should -Be $Scenario.Differences.Count
            if ($Scenario.Differences.Count -eq 0) {
                $results.Value.Status | Should -Be 'Match'
                $driftCount.Value | Should -Be 0
            } else {
                $results.Value.Status | Should -Be 'Drift'
                $driftCount.Value | Should -Be 1
                foreach ($field in $Scenario.Differences) {
                    $results.Value.Differences | Should -Match "${field}: expected="
                }
            }
        }
    }

    Context "Boolean Comparison" {
        It "Should match boolean true (JSON) with string 'true' (API)" {
            $expected = [pscustomobject]@{
                AllowPermanentEligibility = $true
            }
            $live = [pscustomobject]@{
                AllowPermanentEligibleAssignment = "true"
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type "EntraRole" -Name "TestRole" -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Status | Should -Be "Match"
            $driftCount.Value | Should -Be 0
        }

        It "Should match boolean false (JSON) with string 'false' (API)" {
            $expected = [pscustomobject]@{
                AllowPermanentEligibility = $false
            }
            $live = [pscustomobject]@{
                AllowPermanentEligibleAssignment = "false"
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type "EntraRole" -Name "TestRole" -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Status | Should -Be "Match"
            $driftCount.Value | Should -Be 0
        }

        It "Should match string 'True' (JSON) with string 'true' (API)" {
            $expected = [pscustomobject]@{
                AllowPermanentEligibility = "True"
            }
            $live = [pscustomobject]@{
                AllowPermanentEligibleAssignment = "true"
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type "EntraRole" -Name "TestRole" -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Status | Should -Be "Match"
            $driftCount.Value | Should -Be 0
        }
        
        It "Should detect drift when values differ" {
            $expected = [pscustomobject]@{
                AllowPermanentEligibility = $true
            }
            $live = [pscustomobject]@{
                AllowPermanentEligibleAssignment = "false"
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type "EntraRole" -Name "TestRole" -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Status | Should -Be "Drift"
            $driftCount.Value | Should -Be 1
            $results.Value.Differences | Should -Match "expected='true' actual='false'"
        }

        It "Should handle 'None' string correctly (treat as false)" {
             $expected = [pscustomobject]@{
                AllowPermanentEligibility = $false
            }
            $live = [pscustomobject]@{
                AllowPermanentEligibleAssignment = "None"
            }
            $results = [ref]@()
            $driftCount = [ref]0

            Compare-PIMPolicy -Type "EntraRole" -Name "TestRole" -Expected $expected -Live $live -Results $results -DriftCount $driftCount

            $results.Value.Status | Should -Be "Match"
            $driftCount.Value | Should -Be 0
        }
    }
}
