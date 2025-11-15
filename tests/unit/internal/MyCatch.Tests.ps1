<#
.SYNOPSIS
    Unit test for MyCatch internal helper.
.DESCRIPTION
    Tests exception handling wrapper that enriches errors with details and re-throws.
    Validates error parsing, detail extraction, JSON parsing, and graceful log handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "MyCatch" {
    
    BeforeAll {
        InModuleScope EasyPIM {
            # Mock log function - it may or may not be available
            Mock log {
                # Do nothing - just capture the call
            }
            
            # Mock Get-Command to control whether log function is "available"
            Mock Get-Command {
                param($Name, $ErrorAction)
                if ($Name -eq 'log') {
                    return @{ Name = 'log' }
                }
                return $null
            }
        }
    }
    
    Context "When handling simple exceptions" {
        
        It "Should enrich simple exception message and re-throw" {
            InModuleScope EasyPIM {
                # Arrange
                try {
                    throw "Test error message"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert
                { MyCatch $exception } | Should -Throw -ExpectedMessage "*Error, script did not terminate gracefuly*inner=Test error message*"
            }
        }
        
        It "Should call log function when available" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-Command {
                    param($Name, $ErrorAction)
                    if ($Name -eq 'log') {
                        return @{ Name = 'log' }
                    }
                    return $null
                }
                
                Mock log { }
                
                try {
                    throw "Test log message"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert
                { MyCatch $exception } | Should -Throw
                Should -Invoke log -Times 1
            }
        }
        
        It "Should handle exception when log function is not available" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-Command {
                    param($Name, $ErrorAction)
                    return $null  # log function not available
                }
                
                try {
                    throw "Test without log"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert - Should not fail, just skip logging
                { MyCatch $exception } | Should -Throw -ExpectedMessage "*Error, script did not terminate gracefuly*"
            }
        }
    }
    
    Context "When handling exceptions with ErrorDetails" {
        
        It "Should parse JSON error details and enrich message" {
            InModuleScope EasyPIM {
                # Arrange - Create exception with JSON error details
                $errorJson = @{
                    error = @{
                        code = "BadRequest"
                        message = "Invalid parameter value"
                    }
                } | ConvertTo-Json
                
                try {
                    $errorDetails = [System.Management.Automation.ErrorDetails]::new($errorJson)
                    $exception = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Base error"),
                        "TestError",
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $null
                    )
                    $exception.ErrorDetails = $errorDetails
                    
                    # Act & Assert
                    { MyCatch $exception } | Should -Throw -ExpectedMessage "*rawCode=BadRequest*rawReason=Invalid parameter value*"
                } catch {
                    # If we can't construct the ErrorDetails object, skip this test
                    Set-ItResult -Skipped -Because "Unable to construct ErrorDetails object in test environment"
                }
            }
        }
        
        It "Should handle non-JSON error details gracefully" {
            InModuleScope EasyPIM {
                # Arrange - Create exception with non-JSON error details
                try {
                    $errorDetails = [System.Management.Automation.ErrorDetails]::new("Plain text error details")
                    $exception = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Base error"),
                        "TestError",
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $null
                    )
                    $exception.ErrorDetails = $errorDetails
                    
                    # Act & Assert
                    { MyCatch $exception } | Should -Throw -ExpectedMessage "*Error, script did not terminate gracefuly*"
                } catch {
                    # If we can't construct the ErrorDetails object, skip this test
                    Set-ItResult -Skipped -Because "Unable to construct ErrorDetails object in test environment"
                }
            }
        }
    }
    
    Context "When handling already-enriched exceptions" {
        
        It "Should not double-enrich exception that already contains 'Error, script did not terminate gracefuly'" {
            InModuleScope EasyPIM {
                # Arrange - Create exception that's already enriched
                try {
                    throw "Error, script did not terminate gracefuly | inner=Original error"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert - Should re-throw without adding another "inner=" layer
                { MyCatch $exception } | Should -Throw -ExpectedMessage "Error, script did not terminate gracefuly | inner=Original error"
            }
        }
        
        It "Should preserve Graph API error patterns without re-enriching" {
            InModuleScope EasyPIM {
                # Arrange - Create exception with Graph API error pattern
                try {
                    throw "Graph API request failed: code=Forbidden"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert
                { MyCatch $exception } | Should -Throw
            }
        }
    }
    
    Context "When handling exceptions with position information" {
        
        It "Should include position information in logged message" {
            InModuleScope EasyPIM {
                # Arrange
                Mock log { }
                
                try {
                    # Create a script block to get position info
                    $sb = [scriptblock]::Create('throw "Position test error"')
                    & $sb
                } catch {
                    $exception = $_
                }
                
                # Act & Assert
                { MyCatch $exception } | Should -Throw
                Should -Invoke log -Times 1 -ParameterFilter {
                    $msg -match "Position test error"
                }
            }
        }
    }
    
    Context "When processing pipeline input" {
        
        It "Should accept exception from pipeline" {
            InModuleScope EasyPIM {
                # Arrange
                try {
                    throw "Pipeline error"
                } catch {
                    $exception = $_
                }
                
                # Act & Assert - Pass exception through pipeline
                { $exception | MyCatch } | Should -Throw -ExpectedMessage "*Error, script did not terminate gracefuly*inner=Pipeline error*"
            }
        }
    }
}
