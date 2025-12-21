
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
