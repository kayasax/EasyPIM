BeforeAll {
    $internal = Join-Path $PSScriptRoot '..\..\EasyPIM\internal\functions'
    . "$internal\Set-ActiveAssignment.ps1"
    . "$internal\Set-EligibilityAssignment.ps1"
    . "$internal\Invoke-ARM.ps1"
}

Describe 'Assignment expiration payloads (PR #273)' {
    It 'Preserves <Level> expiration contract with Entra=<Entra> and permanent=<Permanent>' -TestCases @(
        foreach ($entra in @($false, $true)) {
            foreach ($permanent in @($false, $true)) {
                foreach ($level in @('Assignment', 'Eligibility')) {
                    @{ Entra = $entra; Permanent = $permanent; Level = $level }
                }
            }
        }
    ) {
        param($Entra, $Permanent, $Level)
        $json = if ($Level -eq 'Assignment') {
            Set-ActiveAssignment -MaximumActiveAssignmentDuration P30D -AllowPermanentActiveAssignment $Permanent -EntraRole:$Entra
        } else {
            Set-EligibilityAssignment -MaximumEligibilityDuration P30D -AllowPermanentEligibility $Permanent -EntraRole:$Entra
        }
        $rule = $json | ConvertFrom-Json
        $rule.isExpirationRequired | Should -BeOfType ([bool])
        $rule.isExpirationRequired | Should -Be (-not $Permanent)
        $rule.id | Should -Be "Expiration_Admin_$Level"
        $rule.target.level | Should -Be $Level
        $rule.target.caller | Should -Be 'Admin'
        @($rule.target.operations) | Should -Contain 'All'
        if ($Permanent) {
            $rule.PSObject.Properties.Name | Should -Not -Contain 'maximumDuration'
        } else {
            $rule.maximumDuration | Should -Be 'P30D'
        }
        if ($Entra) {
            $rule.'@odata.type' | Should -Be '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
        } else {
            $rule.ruleType | Should -Be 'RoleManagementPolicyExpirationRule'
        }
    }

    It 'Preserves Entra eligibility year normalization' {
        $rule = Set-EligibilityAssignment -MaximumEligibilityDuration P1Y -AllowPermanentEligibility $false -EntraRole | ConvertFrom-Json
        $rule.maximumDuration | Should -Be 'P365D'
    }
}

Describe 'ARM error reporting (PR #273)' {
    BeforeEach {
        $savedToken = $env:AZURE_ACCESS_TOKEN
        $env:AZURE_ACCESS_TOKEN = 'offline-test-token'
        Mock Invoke-RestMethod { throw 'Unexpected request' }
    }

    AfterEach {
        $env:AZURE_ACCESS_TOKEN = $savedToken
    }

    It 'Includes the ARM error body in the failure message' {
        Mock Invoke-RestMethod {
            $record = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('400 Bad Request'),
                'OfflineArmError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new(
                '{"error":{"code":"InvalidPolicy","message":"maximumDuration is invalid"}}'
            )
            throw $record
        }
        { Invoke-ARM -restURI 'https://example.invalid/policy' -method PATCH -body '{}' -ErrorAction Stop } |
            Should -Throw '*ARM API call failed: 400 Bad Request*InvalidPolicy*maximumDuration is invalid*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Reports the exception when no response details are available' {
        Mock Invoke-RestMethod { throw 'Offline transport failure' }
        { Invoke-ARM -restURI 'https://example.invalid/policy' -method GET -ErrorAction Stop } |
            Should -Throw '*ARM API call failed: Offline transport failure*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Rethrows the original failure after writing diagnostics' {
        Mock Invoke-RestMethod { throw 'Original ARM failure' }
        Mock Write-Error {}
        { Invoke-ARM -restURI 'https://example.invalid/policy' -method GET } |
            Should -Throw '*Original ARM failure*'
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -eq 'ARM API call failed: Original ARM failure'
        }
    }
}
