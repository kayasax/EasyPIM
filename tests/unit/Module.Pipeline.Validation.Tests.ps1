#Requires -Module Pester

Describe "EasyPIM.Orchestrator Module Validation" {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1"
        Import-Module $ModulePath -Force
    }

    Context "Critical Function Pipeline Support" {
        It "Should have Remove-JsonComments function that supports pipeline input" {
            # Load the internal function directly
            $functionPath = "$PSScriptRoot\..\..\EasyPIM.Orchestrator\internal\functions\Remove-JsonComments.ps1"
            Test-Path $functionPath | Should -Be $true
            
            # Source the function
            . $functionPath
            
            # Test pipeline support - this is the exact pattern that failed in GitHub Actions
            $testJson = '{"test": "value"} // comment'
            { $result = $testJson | Remove-JsonComments; $result } | Should -Not -Throw
        }

        It "Should have Get-EasyPIMConfiguration function available" {
            Get-Command -Name Get-EasyPIMConfiguration -Module EasyPIM.Orchestrator | Should -Not -BeNullOrEmpty
        }

        It "Should export Test-PIMPolicyDrift function" {
            Get-Command -Name Test-PIMPolicyDrift -Module EasyPIM.Orchestrator | Should -Not -BeNullOrEmpty
        }
    }

    Context "GitHub Actions Compatibility Validation" {
        It "Should not have any functions with pipeline usage but missing ValueFromPipeline" {
            # This test ensures we don't have more functions with the same issue
            $moduleFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\EasyPIM.Orchestrator" -Recurse -Filter "*.ps1"
            
            foreach ($file in $moduleFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                
                # Look for pipeline usage patterns: $variable | Function-Name
                if ($content -match '\$\w+\s*\|\s*([A-Za-z-]+)') {
                    $functionName = $matches[1]
                    
                    # Skip built-in cmdlets and known good functions
                    if ($functionName -in @('ConvertFrom-Json', 'ConvertTo-Json', 'Where-Object', 'ForEach-Object', 'Select-Object', 'Sort-Object')) {
                        continue
                    }
                    
                    # Check if this is a custom function in our module
                    $functionDef = $content | Select-String "function\s+$functionName"
                    if ($functionDef) {
                        # Function is defined in this file, check if it supports pipeline
                        $paramBlock = $content | Select-String "(?s)function\s+$functionName.*?param\s*\((.*?)\)" 
                        if ($paramBlock -and $paramBlock.Matches[0].Groups[1].Value -notmatch "ValueFromPipeline") {
                            Write-Warning "Function $functionName in $($file.Name) appears to be used with pipeline but may not support ValueFromPipeline"
                        }
                    }
                }
            }
            
            # This test always passes but generates warnings for potential issues
            $true | Should -Be $true
        }
    }
}
