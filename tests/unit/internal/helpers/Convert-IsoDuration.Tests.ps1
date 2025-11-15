<#
.SYNOPSIS
    Unit test for Convert-IsoDuration internal helper.
.DESCRIPTION
    Tests the Convert-IsoDuration function which validates and normalizes ISO 8601 duration strings.
    Covers valid durations, normalization logic (P[digit][HMS] → PT[digit][HMS]), 
    invalid formats, null handling with -AllowNull switch, and edge cases.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "Convert-IsoDuration" -Tag 'Unit', 'InternalHelper' {
    
    Context "When given valid ISO 8601 durations" {
        
        It "Should accept standard period duration P30D" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P30D"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "P30D"
            }
        }
        
        It "Should accept standard time duration PT1H" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "PT1H"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "PT1H"
            }
        }
        
        It "Should accept complex duration P1Y2M3DT4H5M6S" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P1Y2M3DT4H5M6S"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "P1Y2M3DT4H5M6S"
            }
        }
        
        It "Should accept year-month-day duration P1Y6M15D" {
            InModuleScope EasyPIM {
                # Arrange - Use full date format to avoid ambiguity
                $duration = "P1Y6M15D"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "P1Y6M15D"
            }
        }
    }
    
    Context "When normalizing time components without T prefix" {
        
        It "Should normalize P1H to PT1H" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P1H"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "PT1H"
            }
        }
        
        It "Should normalize P30S to PT30S" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P30S"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "PT30S"
            }
        }
        
        It "Should normalize P5M (5 minutes) to PT5M" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P5M"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "PT5M"
            }
        }
    }
    
    Context "When handling invalid duration formats" {
        
        It "Should throw on invalid format 1H30M" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "1H30M"
                
                # Act & Assert
                { Convert-IsoDuration -Duration $duration } | Should -Throw "*not a valid ISO8601 duration*"
            }
        }
        
        It "Should throw on invalid format P1X" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P1X"
                
                # Act & Assert
                { Convert-IsoDuration -Duration $duration } | Should -Throw "*not a valid ISO8601 duration*"
            }
        }
        
        It "Should throw on empty string without AllowNull" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = ""
                
                # Act & Assert
                { Convert-IsoDuration -Duration $duration } | Should -Throw "*Duration value is empty*"
            }
        }
    }
    
    Context "When handling null and empty values" {
        
        It "Should return null for empty string with -AllowNull" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = ""
                
                # Act
                $result = Convert-IsoDuration -Duration $duration -AllowNull
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should return null for whitespace with -AllowNull" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "   "
                
                # Act
                $result = Convert-IsoDuration -Duration $duration -AllowNull
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When handling edge cases" {
        
        It "Should accept zero duration P0D" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "P0D"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "P0D"
            }
        }
        
        It "Should accept zero time duration PT0S" {
            InModuleScope EasyPIM {
                # Arrange
                $duration = "PT0S"
                
                # Act
                $result = Convert-IsoDuration -Duration $duration
                
                # Assert
                $result | Should -Be "PT0S"
            }
        }
    }
}
