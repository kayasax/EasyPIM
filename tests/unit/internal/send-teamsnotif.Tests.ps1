<#
.SYNOPSIS
    Unit test for send-teamsnotif internal helper.
.DESCRIPTION
    Tests the send-teamsnotif function which sends notifications to Teams webhook.
    Covers message sending, JSON payload formatting, webhook URL usage, HTTP error handling,
    and Invoke-RestMethod mocking. Note: function has typo in source (comment-close before function keyword).
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "send-teamsnotif" -Tag 'Unit', 'InternalHelper' {
    
    BeforeAll {
        # Set script-level webhook URL
        InModuleScope EasyPIM {
            $script:teamsWebhookURL = "https://outlook.office.com/webhook/test-webhook-url"
            $script:description = "Test Description"
            $script:_scriptFullName = "TestScript.ps1"
        }
    }
    
    Context "When sending Teams notifications successfully" {
        
        It "Should call Invoke-RestMethod with correct parameters" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-RestMethod { return $null }
                
                # Act
                send-teamsnotif -message "Test message" -details "Test details"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $URI -eq $script:teamsWebhookURL -and
                    $Method -eq 'POST' -and
                    $ContentType -eq 'application/json'
                }
            }
        }
        
        It "Should send message with correct JSON structure" {
            InModuleScope EasyPIM {
                # Arrange
                $capturedBody = $null
                Mock Invoke-RestMethod { 
                    param($Body)
                    $script:capturedBody = $Body
                    return $null
                }
                
                # Act
                send-teamsnotif -message "Alert message" -details "Details here"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1
                $script:capturedBody | Should -Not -BeNullOrEmpty
                $script:capturedBody | Should -Match "Alert message"
                $script:capturedBody | Should -Match "Details here"
            }
        }
        
        It "Should include message in JSON payload" {
            InModuleScope EasyPIM {
                # Arrange
                $capturedBody = $null
                Mock Invoke-RestMethod { 
                    param($Body)
                    $script:capturedBody = $Body
                    return $null
                }
                
                # Act
                send-teamsnotif -message "Important notification"
                
                # Assert
                $script:capturedBody | Should -Match "Important notification"
            }
        }
        
        It "Should include details in JSON payload when provided" {
            InModuleScope EasyPIM {
                # Arrange
                $capturedBody = $null
                Mock Invoke-RestMethod { 
                    param($Body)
                    $script:capturedBody = $Body
                    return $null
                }
                
                # Act
                send-teamsnotif -message "Error" -details "Stack trace info"
                
                # Assert
                $script:capturedBody | Should -Match "Stack trace info"
            }
        }
        
        It "Should include myStackTrace in payload when provided" {
            InModuleScope EasyPIM {
                # Arrange
                $capturedBody = $null
                Mock Invoke-RestMethod { 
                    param($Body)
                    $script:capturedBody = $Body
                    return $null
                }
                
                # Act
                send-teamsnotif -message "Error" -myStackTrace "at line 123"
                
                # Assert
                $script:capturedBody | Should -Match "at line 123"
            }
        }
    }
    
    Context "When handling HTTP errors" {
        
        It "Should propagate Invoke-RestMethod errors" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-RestMethod { throw "404 Not Found" }
                
                # Act & Assert
                { send-teamsnotif -message "Test" } | Should -Throw "*404*"
            }
        }
        
        It "Should handle 500 Internal Server Error" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-RestMethod { throw "500 Internal Server Error" }
                
                # Act & Assert
                { send-teamsnotif -message "Test" } | Should -Throw "*500*"
            }
        }
    }
    
    Context "When handling edge cases" {
        
        It "Should handle empty details parameter" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Invoke-RestMethod { return $null }
                
                # Act
                send-teamsnotif -message "Message only" -details ""
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1
            }
        }
    }
}
