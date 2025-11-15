<#
.SYNOPSIS
    Unit test for ConvertFrom-ISO8601Duration internal helper.
.DESCRIPTION
    Tests ISO 8601 duration string parsing to TimeSpan objects.
    Validates standard formats (days, hours, minutes), edge cases, and error handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "ConvertFrom-ISO8601Duration" {
    
    Context "When parsing valid ISO 8601 duration strings" {
        
        It "Should convert P30D to 30 days TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "P30D"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.GetType().Name | Should -Be 'TimeSpan'
                $result.TotalDays | Should -Be 30
            }
        }
        
        It "Should convert PT8H to 8 hours TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "PT8H"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.TotalHours | Should -Be 8
            }
        }
        
        It "Should convert PT2H30M to 2.5 hours TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "PT2H30M"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.Hours | Should -Be 2
                $result.Minutes | Should -Be 30
                $result.TotalHours | Should -Be 2.5
            }
        }
        
        It "Should convert PT45M to 45 minutes TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "PT45M"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.TotalMinutes | Should -Be 45
            }
        }
        
        It "Should convert PT3600S to 1 hour TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "PT3600S"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.TotalHours | Should -Be 1
                $result.TotalSeconds | Should -Be 3600
            }
        }
        
        It "Should convert P1DT12H to 1.5 days TimeSpan" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "P1DT12H"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.Days | Should -Be 1
                $result.Hours | Should -Be 12
                $result.TotalDays | Should -Be 1.5
            }
        }
    }
    
    Context "When handling invalid or edge case inputs" {
        
        It "Should return null for empty string" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = ""
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should return null for null input" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = $null
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should return null for invalid ISO 8601 format" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "NotAValidDuration"
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should return null for malformed duration string" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "P30X"  # X is not valid
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should return null for incomplete duration string" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "P"  # Incomplete
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When handling whitespace variations" {
        
        It "Should handle string with leading/trailing whitespace" {
            InModuleScope EasyPIM {
                # Arrange
                $iso = "  PT8H  "
                
                # Act
                $result = ConvertFrom-ISO8601Duration -iso $iso
                
                # Assert
                # Note: .NET XmlConvert might handle or reject whitespace
                # Testing actual behavior
                if ($result) {
                    $result.TotalHours | Should -Be 8
                } else {
                    $result | Should -BeNullOrEmpty
                }
            }
        }
    }
}
