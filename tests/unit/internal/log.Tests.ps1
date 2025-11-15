<#
.SYNOPSIS
    Unit test for log internal helper.
.DESCRIPTION
    Tests the log function which writes messages to file and screen with rotation.
    Covers message logging, file creation, log format, rotation logic, caller context,
    and color-coded console output. Mocks file system operations for isolation.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "log" -Tag 'Unit', 'InternalHelper' {
    
    BeforeAll {
        # Enable logging for tests
        InModuleScope EasyPIM {
            $script:logToFile = $true
            $script:_logPath = "TestDrive:\"
        }
    }
    
    BeforeEach {
        # Reset mocks before each test
        InModuleScope EasyPIM {
            Mock Test-Path { return $false }
            Mock New-Item { return $null }
            Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
            Mock Write-Output { }
            Mock Write-Host { }
        }
    }
    
    Context "When logging is enabled" {
        
        It "Should create log directory if it does not exist" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $false } -ParameterFilter { $_ -like "*LOGS*" }
                Mock New-Item { return $null }
                
                # Act
                log -msg "Test message"
                
                # Assert
                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $ItemType -eq 'Directory'
                }
            }
        }
        
        It "Should create log file if it does not exist" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { param($Path) return $Path -like "*LOGS" } 
                Mock New-Item { return $null }
                
                # Act
                log -msg "Test message"
                
                # Assert
                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $ItemType -eq 'file'
                }
            }
        }
        
        It "Should write message to output stream" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Output { }
                
                # Act
                log -msg "Test log message"
                
                # Assert
                Should -Invoke Write-Output -Times 1 -ParameterFilter {
                    $InputObject -like "*Test log message*"
                }
            }
        }
        
        It "Should display message on screen by default" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Visible message"
                
                # Assert
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $Object -eq "Visible message"
                }
            }
        }
        
        It "Should not display message when -noEcho is set" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Hidden message" -noEcho
                
                # Assert
                Should -Invoke Write-Host -Times 0
            }
        }
    }
    
    Context "When handling log rotation" {
        
        It "Should rotate log when size exceeds MaxSize" {
            InModuleScope EasyPIM {
                # Arrange
                $largeSize = 4000000 # > 3MB default
                Mock Test-Path { return $true }
                Mock Get-ChildItem { 
                    return [PSCustomObject]@{ 
                        Length = $largeSize
                        BaseName = "EasyPIM"
                        DirectoryName = "TestDrive:\LOGS"
                    }
                }
                Mock Rename-Item { }
                Mock Remove-Item { }
                Mock Write-Host { }
                
                # Act
                log -msg "Message triggering rotation"
                
                # Assert
                Should -Invoke Rename-Item -Times 1
            }
        }
        
        It "Should delete old log files beyond MaxFile limit" {
            InModuleScope EasyPIM {
                # Arrange
                $largeSize = 4000000
                Mock Test-Path { return $true }
                Mock Get-ChildItem { 
                    param($Path)
                    if ($Path -like "*EasyPIM*.log") {
                        # Return 5 old log files
                        return @(1..5 | ForEach-Object {
                            [PSCustomObject]@{ 
                                Name = "EasyPIM-$_.log"
                                LastWriteTime = (Get-Date).AddDays(-$_)
                            }
                        })
                    }
                    return [PSCustomObject]@{ 
                        Length = $largeSize
                        BaseName = "EasyPIM"
                        DirectoryName = "TestDrive:\LOGS"
                    }
                }
                Mock Rename-Item { }
                Mock Remove-Item { }
                Mock Write-Host { }
                
                # Act
                log -msg "Rotation with cleanup"
                
                # Assert
                Should -Invoke Remove-Item -Times 1
            }
        }
        
        It "Should not rotate when file size is below MaxSize" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Rename-Item { }
                Mock Write-Host { }
                
                # Act
                log -msg "Small log message"
                
                # Assert
                Should -Invoke Rename-Item -Times 0
            }
        }
    }
    
    Context "When handling color-coded output" {
        
        It "Should display error messages in red" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Error occurred"
                
                # Assert
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $ForegroundColor -eq 'red'
                }
            }
        }
        
        It "Should display warning messages in yellow" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Warning: check this"
                
                # Assert
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $ForegroundColor -eq 'yellow'
                }
            }
        }
        
        It "Should display success messages in green" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Success: operation completed"
                
                # Assert
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $ForegroundColor -eq 'green'
                }
            }
        }
        
        It "Should display info messages in cyan" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return [PSCustomObject]@{ Length = 1000 } }
                Mock Write-Host { }
                
                # Act
                log -msg "Info: processing started"
                
                # Assert
                Should -Invoke Write-Host -Times 1 -ParameterFilter {
                    $ForegroundColor -eq 'cyan'
                }
            }
        }
    }
    
    Context "When logging is disabled" {
        
        It "Should not log when logToFile is false" {
            InModuleScope EasyPIM {
                # Arrange
                $script:logToFile = $false
                Mock Test-Path { return $true }
                Mock Write-Output { }
                Mock Write-Host { }
                
                # Act
                log -msg "Should not be logged"
                
                # Assert
                Should -Invoke Write-Output -Times 0
                Should -Invoke Write-Host -Times 1 # Still displays
            }
        }
    }
}
