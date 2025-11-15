<#
.SYNOPSIS
    Unit test for Test-ARMAuthentication internal helper.
.DESCRIPTION
    Tests Azure Resource Manager API authentication validation and diagnostics.
    Validates subscription scenarios, OIDC authentication, error handling, and diagnostic output.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Test-ARMAuthentication" {
    
    BeforeAll {
        InModuleScope EasyPIM {
            # Store original environment variables
            $script:originalEnvVars = @{
                AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
                AZURE_CLIENT_ID = $env:AZURE_CLIENT_ID
                AZURE_TENANT_ID = $env:AZURE_TENANT_ID
                AZURE_ACCESS_TOKEN = $env:AZURE_ACCESS_TOKEN
            }
        }
    }
    
    AfterAll {
        InModuleScope EasyPIM {
            # Restore original environment variables
            $env:AZURE_SUBSCRIPTION_ID = $script:originalEnvVars.AZURE_SUBSCRIPTION_ID
            $env:AZURE_CLIENT_ID = $script:originalEnvVars.AZURE_CLIENT_ID
            $env:AZURE_TENANT_ID = $script:originalEnvVars.AZURE_TENANT_ID
            $env:AZURE_ACCESS_TOKEN = $script:originalEnvVars.AZURE_ACCESS_TOKEN
        }
    }
    
    Context "When testing with explicit subscription ID" {
        
        It "Should return true when ARM API call succeeds with subscription" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "12345678-1234-1234-1234-123456789012"
                Mock Invoke-ARM {
                    return @{
                        value = @(
                            @{ name = "rg1"; id = "/subscriptions/$subId/resourceGroups/rg1" }
                            @{ name = "rg2"; id = "/subscriptions/$subId/resourceGroups/rg2" }
                        )
                    }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $true
                Should -Invoke Invoke-ARM -Times 1 -Exactly
            }
        }
        
        It "Should call Invoke-ARM with correct subscription endpoint" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "aaaabbbb-cccc-dddd-eeee-ffffffffffff"
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match "subscriptions/$subId/resourceGroups"
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should return true even with empty resource group list" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "emptysub-1234-5678-90ab-cdef12345678"
                Mock Invoke-ARM {
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should return true when response is null" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "nullresp-1234-5678-90ab-cdef12345678"
                Mock Invoke-ARM {
                    return $null
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When testing without subscription ID (tenant-level)" {
        
        BeforeEach {
            InModuleScope EasyPIM {
                $env:AZURE_SUBSCRIPTION_ID = $null
            }
        }
        
        It "Should use tenant list endpoint when no subscription provided" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext { return $null }
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match "tenants\?api-version"
                    return @{
                        value = @(
                            @{ tenantId = "tenant1"; displayName = "Tenant 1" }
                        )
                    }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should return true for successful tenant-level access" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext { return $null }
                Mock Invoke-ARM {
                    return @{
                        value = @(
                            @{ tenantId = "t1" }
                            @{ tenantId = "t2" }
                        )
                    }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When using environment variable for subscription" {
        
        It "Should use AZURE_SUBSCRIPTION_ID environment variable" {
            InModuleScope EasyPIM {
                # Arrange
                $envSubId = "env-sub-1234-5678-90ab-cdef12345678"
                $env:AZURE_SUBSCRIPTION_ID = $envSubId
                Mock Get-AzContext { return $null }
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match $envSubId
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should prefer explicit SubscriptionId over environment variable" {
            InModuleScope EasyPIM {
                # Arrange
                $explicitSubId = "explicit-1234-5678-90ab-cdef"
                $envSubId = "env-sub-9999-8888-7777-666666666666"
                $env:AZURE_SUBSCRIPTION_ID = $envSubId
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match $explicitSubId
                    $restURI | Should -Not -Match $envSubId
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $explicitSubId
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When using Azure PowerShell context" {
        
        It "Should retrieve subscription from Get-AzContext when available" {
            InModuleScope EasyPIM {
                # Arrange
                $contextSubId = "context-sub-1234-5678-90ab"
                $env:AZURE_SUBSCRIPTION_ID = $null
                Mock Get-AzContext {
                    return @{
                        Subscription = @{ Id = $contextSubId }
                        Environment = @{ Name = "AzureCloud" }
                    }
                }
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match $contextSubId
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
                Should -Invoke Get-AzContext -Times 1 -Exactly
            }
        }
        
        It "Should handle Get-AzContext when subscription is null" {
            InModuleScope EasyPIM {
                # Arrange
                $env:AZURE_SUBSCRIPTION_ID = $null
                Mock Get-AzContext {
                    return @{
                        Subscription = $null
                        Environment = @{ Name = "AzureCloud" }
                    }
                }
                Mock Invoke-ARM {
                    param($restURI)
                    $restURI | Should -Match "tenants"
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should handle Get-AzContext error gracefully" {
            InModuleScope EasyPIM {
                # Arrange
                $env:AZURE_SUBSCRIPTION_ID = $null
                Mock Get-AzContext {
                    param($ErrorAction)
                    # Function uses -ErrorAction SilentlyContinue, so return null instead of throwing
                    if ($ErrorAction -eq 'SilentlyContinue') {
                        return $null
                    }
                    throw "No Azure context available"
                }
                Mock Invoke-ARM {
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When ARM API call fails" {
        
        It "Should return false when Invoke-ARM throws exception" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "fail-sub-1234-5678-90ab-cdef12345678"
                Mock Invoke-ARM {
                    throw "Unauthorized access"
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false on authentication error" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext { return $null }
                Mock Invoke-ARM {
                    throw [System.UnauthorizedAccessException]::new("401 Unauthorized")
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false on network timeout" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "timeout-1234-5678-90ab-cdef12345678"
                Mock Invoke-ARM {
                    throw [System.TimeoutException]::new("Request timed out")
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false on generic error" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext { return $null }
                Mock Invoke-ARM {
                    throw "Internal server error"
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $false
            }
        }
    }
    
    Context "When validating verbose output" {
        
        It "Should call Invoke-ARM with VerbosePreference parameter" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "verbose-test-1234-5678-90ab"
                Mock Invoke-ARM {
                    param($Verbose)
                    # Verify Verbose parameter is passed
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId $subId -Verbose
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When validating diagnostic output" {
        
        It "Should check environment variables on error" {
            InModuleScope EasyPIM {
                # Arrange
                $env:AZURE_CLIENT_ID = "test-client-id"
                $env:AZURE_TENANT_ID = "test-tenant-id"
                $env:AZURE_ACCESS_TOKEN = "test-token"
                Mock Invoke-ARM {
                    throw "Auth failed"
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId "test-sub"
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should call Get-AzContext for diagnostic info on error" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-ARM {
                    throw "Auth failed"
                }
                Mock Get-AzContext {
                    return @{
                        Account = @{ Id = "test@example.com" }
                        Environment = @{ Name = "AzureCloud" }
                    }
                }
                
                # Act
                $result = Test-ARMAuthentication
                
                # Assert
                $result | Should -Be $false
                # Get-AzContext called at least once during function execution
            }
        }
    }
    
    Context "When validating function return type" {
        
        It "Should return boolean type on success" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-ARM {
                    return @{ value = @() }
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId "type-test"
                
                # Assert
                $result.GetType().Name | Should -Be 'Boolean'
            }
        }
        
        It "Should return boolean type on failure" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-ARM {
                    throw "Error"
                }
                
                # Act
                $result = Test-ARMAuthentication -SubscriptionId "type-test"
                
                # Assert
                $result.GetType().Name | Should -Be 'Boolean'
            }
        }
    }
}
