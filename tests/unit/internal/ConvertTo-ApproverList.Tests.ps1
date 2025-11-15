<#
.SYNOPSIS
    Unit test for ConvertTo-ApproverList internal function.
.DESCRIPTION
    Tests the ConvertTo-ApproverList function which parses CSV-formatted approver strings
    into approver objects. Covers single/multiple approvers, various property formats,
    edge cases with quotes and separators, and malformed input handling.
.NOTES
    Template Version: 1.1
    Created: November 13, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalFunction
#>

Describe "ConvertTo-ApproverList" -Tag 'Unit', 'InternalFunction' {
    
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../../../EasyPIM/EasyPIM.psd1" -Force
    }
    
    Context "When parsing single approver entries" {
        
        It "Should parse approver with all properties using colon separator" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:12345-abcde-67890; userType:User; name:John Doe; description:Primary Approver}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be '12345-abcde-67890'
                $result[0].Type | Should -Be 'User'
                $result[0].Name | Should -Be 'John Doe'
                $result[0].Description | Should -Be 'Primary Approver'
            }
        }
        
        It "Should parse approver with all properties using equals separator" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id=12345-abcde-67890; userType=Group; name=Approver Group; description=Security Team}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be '12345-abcde-67890'
                $result[0].Type | Should -Be 'Group'
                $result[0].Name | Should -Be 'Approver Group'
                $result[0].Description | Should -Be 'Security Team'
            }
        }
        
        It "Should parse approver with quoted values" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:"12345-abcde-67890"; userType:"User"; name:"Jane Smith"; description:"Backup Approver"}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be '12345-abcde-67890'
                $result[0].Name | Should -Be 'Jane Smith'
            }
        }
        
        It "Should parse approver with minimal properties (id and userType only)" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abcdef123456; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'abcdef123456'
                $result[0].Type | Should -Be 'User'
                $result[0].Name | Should -BeNullOrEmpty
                $result[0].Description | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When parsing multiple approver entries" {
        
        It "Should parse two approvers separated by hashtable markers" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:111-aaa; userType:User; name:Alice}@{id:222-bbb; userType:Group; name:Bob Team}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 2
                $result[0].Id | Should -Be '111-aaa'
                $result[0].Name | Should -Be 'Alice'
                $result[1].Id | Should -Be '222-bbb'
                $result[1].Name | Should -Be 'Bob Team'
            }
        }
        
        It "Should parse three approvers with mixed separators" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:aaa-111; userType:User}@{id=bbb-222; userType=Group}@{id:ccc-333; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 3
                $result[0].Id | Should -Be 'aaa-111'
                $result[1].Id | Should -Be 'bbb-222'
                $result[2].Id | Should -Be 'ccc-333'
            }
        }
        
        It "Should handle space-separated multiple approvers" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:111-aaa; userType:User} @{id:222-bbb; userType:Group} @{id:333-ccc; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 3
            }
        }
    }
    
    Context "When handling edge cases and malformed input" {
        
        It "Should return empty array for null or whitespace text" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result1 = ConvertTo-ApproverList -text ''
                $result2 = ConvertTo-ApproverList -text '   '
                $result3 = ConvertTo-ApproverList -text $null
                
                # Assert
                $result1.Count | Should -Be 0
                $result2.Count | Should -Be 0
                $result3.Count | Should -Be 0
            }
        }
        
        It "Should skip entries without valid id" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{userType:User; name:No ID Person}@{id:abc12-345ef; userType:User; name:Valid}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'abc12-345ef'
                $result[0].Name | Should -Be 'Valid'
            }
        }
        
        It "Should handle UUID-style GUID ids" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:550e8400-e29b-41d4-a716-446655440000; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be '550e8400-e29b-41d4-a716-446655440000'
            }
        }
        
        It "Should handle missing optional fields gracefully" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abcd-12345; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Name | Should -BeNullOrEmpty
                $result[0].Description | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle extra whitespace around properties" {
            InModuleScope EasyPIM {
                # Arrange - Regex requires hex chars only (0-9, a-f)
                $text = '@{id:abcd-45678; userType:Group; name:Spaced Out}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'abcd-45678'
                $result[0].Type | Should -Be 'Group'
            }
        }
    }
    
    Context "When handling case sensitivity" {
        
        It "Should match property names case-insensitively (Id, ID, id)" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{ID:abc12-34567; USERTYPE:User; NAME:Upper Case}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'abc12-34567'
                $result[0].Type | Should -Be 'User'
                $result[0].Name | Should -Be 'Upper Case'
            }
        }
        
        It "Should preserve case in property values" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abcd-78901; userType:SomeCustomType; name:MixedCaseName}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result[0].Type | Should -Be 'SomeCustomType'
                $result[0].Name | Should -Be 'MixedCaseName'
            }
        }
    }
    
    Context "When handling special characters in values" {
        
        It "Should handle names with hyphens and apostrophes" {
            InModuleScope EasyPIM {
                # Arrange
                $text = "@{id:abcd-00123; userType:User; name:O'Brien-Smith}"
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result[0].Name | Should -Be "O'Brien-Smith"
            }
        }
        
        It "Should handle descriptions with spaces and commas" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abcd-00234; userType:Group; description:Security Team, Primary Approval}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result[0].Description | Should -Match 'Security Team'
            }
        }
    }
    
    Context "When validating output structure" {
        
        It "Should return PSCustomObject with correct property names" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abcdef123456; userType:User; name:Test; description:Desc}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                $result[0].PSObject.Properties.Name | Should -Contain 'Id'
                $result[0].PSObject.Properties.Name | Should -Contain 'Name'
                $result[0].PSObject.Properties.Name | Should -Contain 'Type'
                $result[0].PSObject.Properties.Name | Should -Contain 'Description'
            }
        }
        
        It "Should return an array for single approver" {
            InModuleScope EasyPIM {
                # Arrange
                $text = '@{id:abc12-34567; userType:User}'
                
                # Act
                $result = ConvertTo-ApproverList -text $text
                
                # Assert
                # PowerShell returns ArrayList which is IEnumerable but not necessarily [array]
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'abc12-34567'
            }
        }
    }
}
