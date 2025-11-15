<#
.SYNOPSIS
    Unit test for Format-TimeSpanHuman internal helper.
.DESCRIPTION
    Tests TimeSpan to human-readable string formatting.
    Validates all formatting branches: days, hours, minutes, seconds, and combinations.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Format-TimeSpanHuman" {
    
    Context "When formatting TimeSpan with only days" {
        
        It "Should format 30 days as '30d'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 30
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "30d"
            }
        }
        
        It "Should format 1 day as '1d'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 1
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "1d"
            }
        }
        
        It "Should format 365 days as '365d'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 365
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "365d"
            }
        }
    }
    
    Context "When formatting TimeSpan with days and hours" {
        
        It "Should format 2 days 8 hours as '2d 8h'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 2 -Hours 8
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "2d 8h"
            }
        }
        
        It "Should format 1 day 1 hour as '1d 1h'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 1 -Hours 1
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "1d 1h"
            }
        }
    }
    
    Context "When formatting TimeSpan with only hours" {
        
        It "Should format 8 hours as '8h'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Hours 8
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "8h"
            }
        }
        
        It "Should format 1 hour as '1h'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Hours 1
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "1h"
            }
        }
        
        It "Should format 24 hours as '1d' (day conversion)" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Hours 24
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                # 24 hours = 1 day, so it formats as "1d"
                $result | Should -Be "1d"
            }
        }
    }
    
    Context "When formatting TimeSpan with hours and minutes" {
        
        It "Should format 2 hours 30 minutes as '2h 30m'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Hours 2 -Minutes 30
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "2h 30m"
            }
        }
        
        It "Should format 8 hours 15 minutes as '8h 15m'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Hours 8 -Minutes 15
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "8h 15m"
            }
        }
    }
    
    Context "When formatting TimeSpan with only minutes" {
        
        It "Should format 45 minutes as '45m'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Minutes 45
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "45m"
            }
        }
        
        It "Should format 1 minute as '1m'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Minutes 1
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "1m"
            }
        }
        
        It "Should format 59 minutes as '59m'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Minutes 59
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "59m"
            }
        }
    }
    
    Context "When formatting TimeSpan with only seconds" {
        
        It "Should format 30 seconds as '30s'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Seconds 30
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "30s"
            }
        }
        
        It "Should format 1 second as '1s'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Seconds 1
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "1s"
            }
        }
        
        It "Should format 59 seconds as '59s'" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Seconds 59
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "59s"
            }
        }
    }
    
    Context "When handling edge cases and null inputs" {
        
        It "Should handle empty/zero TimeSpan gracefully" {
            InModuleScope EasyPIM {
                # Arrange - Test the null guard inside the function
                # Note: Can't pass $null directly due to type constraint
                # Testing with zero TimeSpan instead
                $ts = New-TimeSpan -Seconds 0
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "0s"
            }
        }
        
        It "Should return '0s' for zero TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Seconds 0
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "0s"
            }
        }
        
        It "Should handle fractional seconds and round to nearest second" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Milliseconds 1500  # 1.5 seconds
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "2s"  # Should round to 2
            }
        }
    }
    
    Context "When formatting complex TimeSpan combinations" {
        
        It "Should format 5 days 3 hours 25 minutes as '5d 3h' (ignores minutes when days present)" {
            InModuleScope EasyPIM {
                # Arrange
                $ts = New-TimeSpan -Days 5 -Hours 3 -Minutes 25
                
                # Act
                $result = Format-TimeSpanHuman -ts $ts
                
                # Assert
                $result | Should -Be "5d 3h"
            }
        }
    }
}
