Describe "EasyPIM Multi-Cloud Integration Tests" -Tag 'Integration' {
    
    Context "Module Import and Initialization" {
        It "Should import EasyPIM module without errors" {
            { Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force } | Should -Not -Throw
        }
        
        It "Should have updated module version" {
            $manifest = Import-PowerShellDataFile "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
            $manifest.ModuleVersion | Should -BeGreaterOrEqual '1.10.0'
        }
        
        It "Should use custom dependency management instead of RequiredModules" {
            $manifest = Import-PowerShellDataFile "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
            
            # Verify RequiredModules is commented out (module uses custom dependency checks)
            $manifest.RequiredModules | Should -BeNullOrEmpty
            
            # Verify custom dependency check script is configured
            $manifest.ScriptsToProcess | Should -Contain 'internal\scripts\Import-ModuleChecks.ps1'
            
            # Verify the dependency check script exists
            "$PSScriptRoot\..\EasyPIM\internal\scripts\Import-ModuleChecks.ps1" | Should -Exist
        }
        
        It "Should include initialization script in manifest" {
            $manifest = Import-PowerShellDataFile "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
            $manifest.ScriptsToProcess | Should -Contain 'internal\scripts\Import-ModuleChecks.ps1'
        }
    }
    
    Context "Endpoint Discovery Functions" {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force
        }
        
        It "Should have Get-PIMAzureEnvironmentEndpoint available internally" {
            $internalFunctions = Get-ChildItem "$PSScriptRoot\..\EasyPIM\internal\functions" -Filter "*.ps1"
            $internalFunctions.Name | Should -Contain "Get-PIMAzureEnvironmentEndpoint.ps1"
        }
        
        It "Should have Import-ModuleChecks script available" {
            $scriptFiles = Get-ChildItem "$PSScriptRoot\..\EasyPIM\internal\scripts" -Filter "*.ps1"
            $scriptFiles.Name | Should -Contain "Import-ModuleChecks.ps1"
        }
    }
    
    Context "Modified Functions Use Dynamic Endpoints" {
        
        It "Should not contain hardcoded management.azure.com in key ARM functions" {
            $armFunctions = @(
                'Invoke-ARM.ps1',
                'Get-AllPolicies.ps1', 
                'get-config.ps1',
                'Update-Policy.ps1'
            )
            
            $hardcodedFiles = @()
            foreach ($funcName in $armFunctions) {
                $funcPath = "$PSScriptRoot\..\EasyPIM\internal\functions\$funcName"
                if (Test-Path $funcPath) {
                    $content = Get-Content $funcPath -Raw
                    if ($content -match '"https://management\.azure\.com"' -and 
                        $content -notmatch 'Get-PIMAzureEnvironmentEndpoint') {
                        $hardcodedFiles += $funcName
                    }
                }
            }
            
            $hardcodedFiles | Should -BeNullOrEmpty
        }
        
        It "Should not contain hardcoded management.azure.com in public Azure Resource functions" {
            $publicFunctions = Get-ChildItem "$PSScriptRoot\..\EasyPIM\functions" -Filter "*AzureResource*.ps1"
            $hardcodedFiles = @()
            
            foreach ($file in $publicFunctions) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match '"https://management\.azure\.com"' -and 
                    $content -notmatch 'Get-PIMAzureEnvironmentEndpoint') {
                    $hardcodedFiles += $file.Name
                }
            }
            
            $hardcodedFiles | Should -BeNullOrEmpty
        }
        
        It "Should use Get-PIMAzureEnvironmentEndpoint in updated functions" {
            $updatedFunctions = @(
                'internal\functions\Invoke-ARM.ps1',
                'internal\functions\Invoke-graph.ps1',
                'functions\New-PIMAzureResourceActiveAssignment.ps1',
                'functions\Get-PIMAzureResourceActiveAssignment.ps1'
            )
            
            foreach ($funcPath in $updatedFunctions) {
                $fullPath = "$PSScriptRoot\..\EasyPIM\$funcPath"
                if (Test-Path $fullPath) {
                    $content = Get-Content $fullPath -Raw
                    $content | Should -Match 'Get-PIMAzureEnvironmentEndpoint'
                }
            }
        }
        
        It "Should not contain hardcoded graph.microsoft.com in updated Graph functions" {
            $graphFunctions = @(
                'internal\functions\Invoke-graph.ps1',
                'functions\Get-PIMEntraRolePendingApproval.ps1',
                'internal\functions\Test-PrincipalExists.ps1'
            )
            
            $hardcodedFiles = @()
            foreach ($funcPath in $graphFunctions) {
                $fullPath = "$PSScriptRoot\..\EasyPIM\$funcPath"
                if (Test-Path $fullPath) {
                    $content = Get-Content $fullPath -Raw
                    if ($content -match '"https://graph\.microsoft\.com"' -and 
                        $content -notmatch 'Get-PIMAzureEnvironmentEndpoint') {
                        $hardcodedFiles += $funcPath
                    }
                }
            }
            
            $hardcodedFiles | Should -BeNullOrEmpty
        }
    }
    
    Context "Backward Compatibility" {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force
        }
        
        It "Should still export all original public functions" {
            $exportedFunctions = Get-Command -Module EasyPIM -CommandType Function
            $expectedFunctions = @(
                'Get-PIMAzureResourceActiveAssignment',
                'Get-PIMAzureResourceEligibleAssignment',
                'New-PIMAzureResourceActiveAssignment',
                'Get-PIMEntraRoleActiveAssignment',
                'Get-PIMGroupActiveAssignment'
            )
            
            foreach ($func in $expectedFunctions) {
                $exportedFunctions.Name | Should -Contain $func
            }
        }
        
        It "Should maintain function parameter compatibility" {
            $function = Get-Command Get-PIMAzureResourceActiveAssignment
            $function.Parameters.Keys | Should -Contain 'tenantID'
            $function.Parameters.Keys | Should -Contain 'subscriptionID'
            $function.Parameters.Keys | Should -Contain 'scope'
        }
    }
    
    Context "Error Handling and Resilience" {
        
        It "Should handle missing Azure context gracefully in endpoint discovery" {
            Mock Get-AzContext { $null } -ModuleName EasyPIM
            
            # This should not crash the module import
            { Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force } | Should -Not -Throw
        }
        
        It "Should return true when all dependencies are installed" {
            # Import the dependency check script to access the function
            . "$PSScriptRoot\..\EasyPIM\internal\scripts\Import-ModuleChecks.ps1"
            
            # Since our test environment has the required modules installed,
            # Test-EasyPIMDependencies should return true and generate no warnings
            $result = Test-EasyPIMDependencies
            $result | Should -Be $true
        }
        
        It "Should validate dependencies are properly installed" {
            # Import the dependency check script to access the function
            . "$PSScriptRoot\..\EasyPIM\internal\scripts\Import-ModuleChecks.ps1"
            
            # Since our test environment has the required modules installed,
            # Test-EasyPIMDependencies should return true and generate no warnings
            $result = Test-EasyPIMDependencies
            $result | Should -Be $true
        }
    }
    
    Context "Multi-Cloud Environment Simulation" {
        
        It "Should handle US Government cloud configuration" {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureUSGovernment'
                        ResourceManagerUrl = 'https://management.usgovcloudapi.net/'
                    }
                }
            } -ModuleName EasyPIM
            
            Mock Get-MgEnvironment {
                @{
                    GraphEndpoint = 'https://graph.microsoft.us'
                }
            } -ModuleName EasyPIM
            
            # This should work without errors
            { Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force } | Should -Not -Throw
        }
        
        It "Should handle China cloud configuration" {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureChinaCloud'
                        ResourceManagerUrl = 'https://management.chinacloudapi.cn/'
                    }
                }
            } -ModuleName EasyPIM
            
            Mock Get-MgEnvironment {
                @{
                    GraphEndpoint = 'https://microsoftgraph.chinacloudapi.cn'
                }
            } -ModuleName EasyPIM
            
            # This should work without errors
            { Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force } | Should -Not -Throw
        }
    }
}
