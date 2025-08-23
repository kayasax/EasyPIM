BeforeAll {
    . "$PSScriptRoot\..\EasyPIM\internal\scripts\Import-ModuleChecks.ps1"
    
    # Check if required modules are available and create stubs if needed
    $script:AzAccountsAvailable = $null -ne (Get-Module Az.Accounts -ListAvailable)
    $script:MgGraphAvailable = $null -ne (Get-Module Microsoft.Graph.Authentication -ListAvailable)
    
    # Create stub functions if modules aren't available
    if (-not $script:AzAccountsAvailable) {
        function Global:Get-AzContext { return $null }
    }
    
    if (-not $script:MgGraphAvailable) {
        function Global:Get-MgContext { return $null }
    }
}

Describe "Test-EasyPIMDependencies" {
    
    Context "When all required modules are installed" {
        BeforeEach {
            Mock Get-Module -ParameterFilter { $ListAvailable } {
                @(
                    [PSCustomObject]@{ Name = 'Microsoft.Graph.Authentication'; Version = '2.10.0' }
                    [PSCustomObject]@{ Name = 'Microsoft.Graph.Identity.Governance'; Version = '2.10.0' }
                    [PSCustomObject]@{ Name = 'Az.Accounts'; Version = '2.13.0' }
                )
            }
            Mock Write-Warning {}
        }
        
        It "Should return true" {
            $result = Test-EasyPIMDependencies
            $result | Should -Be $true
        }
        
        It "Should not write any warnings" {
            Test-EasyPIMDependencies
            Should -Invoke Write-Warning -Times 0
        }
        
        It "Should set dependency flags correctly" {
            Test-EasyPIMDependencies
            $script:DependenciesMissing | Should -Be $false
            $script:MissingModuleNames | Should -BeNullOrEmpty
        }
    }
    
    Context "When Microsoft.Graph modules are missing" {
        BeforeEach {
            # Actually mock the modules to appear as missing
            Mock Get-Module -ParameterFilter { $Name -eq 'Microsoft.Graph.Authentication' -and $ListAvailable } { @() }
            Mock Get-Module -ParameterFilter { $Name -eq 'Microsoft.Graph.Identity.Governance' -and $ListAvailable } { @() }
            Mock Get-Module -ParameterFilter { $Name -eq 'Az.Accounts' -and $ListAvailable } {
                @(
                    [PSCustomObject]@{ Name = 'Az.Accounts'; Version = '2.13.0' }
                )
            }
            Mock Write-Warning {}
        }
        
        It "Should return false" {
            $result = Test-EasyPIMDependencies
            $result | Should -Be $false
        }
        
        It "Should write warnings about missing modules" {
            Test-EasyPIMDependencies
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*Microsoft.Graph.Authentication*"
            }
        }
        
        It "Should provide installation instructions" {
            Test-EasyPIMDependencies
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*Install-Module*"
            }
        }
        
        It "Should set dependency flags correctly" {
            Test-EasyPIMDependencies
            $script:DependenciesMissing | Should -Be $true
            $script:MissingModuleNames | Should -Contain 'Microsoft.Graph.Authentication'
            $script:MissingModuleNames | Should -Contain 'Microsoft.Graph.Identity.Governance'
        }
    }
    
    Context "When Az.Accounts module is missing" {
        BeforeEach {
            Mock Get-Module -ParameterFilter { $ListAvailable } {
                @(
                    [PSCustomObject]@{ Name = 'Microsoft.Graph.Authentication'; Version = '2.10.0' }
                    [PSCustomObject]@{ Name = 'Microsoft.Graph.Identity.Governance'; Version = '2.10.0' }
                )
            }
            Mock Write-Warning {}
        }
        
        It "Should return false" {
            $result = Test-EasyPIMDependencies
            $result | Should -Be $false
        }
        
        It "Should warn about missing Az.Accounts" {
            Test-EasyPIMDependencies
            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*Az.Accounts*"
            }
        }
    }
    
    Context "When modules have incorrect versions" {
        BeforeEach {
            Mock Get-Module -ParameterFilter { $Name -eq 'Microsoft.Graph.Authentication' -and $ListAvailable } {
                @([PSCustomObject]@{ Name = 'Microsoft.Graph.Authentication'; Version = '1.0.0' })  # Too old
            }
            Mock Get-Module -ParameterFilter { $Name -eq 'Microsoft.Graph.Identity.Governance' -and $ListAvailable } {
                @([PSCustomObject]@{ Name = 'Microsoft.Graph.Identity.Governance'; Version = '2.10.0' })
            }
            Mock Get-Module -ParameterFilter { $Name -eq 'Az.Accounts' -and $ListAvailable } {
                @([PSCustomObject]@{ Name = 'Az.Accounts'; Version = '2.0.0' })  # Too old
            }
            Mock Write-Warning {}
        }
        
        It "Should detect version mismatch" {
            $result = Test-EasyPIMDependencies
            $result | Should -Be $false
        }
        
        It "Should warn about outdated modules" {
            Test-EasyPIMDependencies
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*Outdated*"
            }
        }
        
        It "Should show current and required versions" {
            Test-EasyPIMDependencies
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*version*"
            }
        }
    }
    
    Context "When no modules are installed" {
        BeforeEach {
            Mock Get-Module -ParameterFilter { $ListAvailable } { @() }
            Mock Write-Warning {}
        }
        
        It "Should return false" {
            $result = Test-EasyPIMDependencies
            $result | Should -Be $false
        }
        
        It "Should warn about all missing modules" {
            Test-EasyPIMDependencies
            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*Missing required modules*"
            }
        }
        
        It "Should provide batch installation command" {
            Test-EasyPIMDependencies
            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*install all at once*"
            }
        }
    }
}

Describe "Test-AzureConnections" {
    
    Context "When both Azure and Graph connections exist" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureCloud'
                    }
                }
            }
            Mock Get-MgContext {
                @{
                    Environment = 'Global'
                }
            }
            Mock Write-Verbose {}
        }
        
        It "Should return connection status" {
            $result = Test-AzureConnections
            $result.AzConnected | Should -Be $true
            $result.MgConnected | Should -Be $true
            $result.AzEnvironment | Should -Be 'AzureCloud'
            $result.MgEnvironment | Should -Be 'Global'
        }
        
        It "Should log successful connections" {
            Test-AzureConnections
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Connected to Azure environment: AzureCloud*"
            }
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Connected to Microsoft Graph environment: Global*"
            }
        }
    }
    
    Context "When no connections exist" {
        BeforeEach {
            Mock Get-AzContext { $null }
            Mock Get-MgContext { $null }
            Mock Write-Verbose {}
        }
        
        It "Should return disconnected status" {
            $result = Test-AzureConnections
            $result.AzConnected | Should -Be $false
            $result.MgConnected | Should -Be $false
            $result.AzEnvironment | Should -BeNullOrEmpty
            $result.MgEnvironment | Should -BeNullOrEmpty
        }
        
        It "Should suggest connection commands" {
            Test-AzureConnections
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Connect-AzAccount*"
            }
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Connect-MgGraph*"
            }
        }
    }
    
    Context "When only Azure connection exists" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureUSGovernment'
                    }
                }
            }
            Mock Get-MgContext { $null }
            Mock Write-Verbose {}
        }
        
        It "Should return partial connection status" {
            $result = Test-AzureConnections
            $result.AzConnected | Should -Be $true
            $result.MgConnected | Should -Be $false
            $result.AzEnvironment | Should -Be 'AzureUSGovernment'
            $result.MgEnvironment | Should -BeNullOrEmpty
        }
    }
}
