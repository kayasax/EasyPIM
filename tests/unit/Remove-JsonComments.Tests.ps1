#Requires -Module Pester

Describe "Remove-JsonComments Function Tests" {
    BeforeAll {
        # Import the function directly for testing
        . "$PSScriptRoot\..\..\EasyPIM.Orchestrator\internal\functions\Remove-JsonComments.ps1"
    }

    Context "Parameter-based usage" {
        It "Should remove line comments" {
            $json = @"
{
    "test": "value", // This is a line comment
    "another": "value2"
}
"@
            $result = Remove-JsonComments -Content $json
            $result | Should -Not -Match "//"
            $result | Should -Match '"test"'
            $result | Should -Match '"another"'
        }

        It "Should remove block comments" {
            $json = @"
{
    "test": "value", /* This is a block comment */
    "another": "value2"
}
"@
            $result = Remove-JsonComments -Content $json
            $result | Should -Not -Match "/\*"
            $result | Should -Not -Match "\*/"
            $result | Should -Match '"test"'
        }

        It "Should handle multi-line block comments" {
            $json = @"
{
    "test": "value",
    /* This is a 
       multi-line
       block comment */
    "another": "value2"
}
"@
            $result = Remove-JsonComments -Content $json
            $result | Should -Not -Match "/\*"
            $result | Should -Not -Match "\*/"
            $result | Should -Match '"test"'
            $result | Should -Match '"another"'
        }
    }

    Context "Pipeline usage (CRITICAL for GitHub Actions)" {
        It "Should accept input from pipeline" {
            $json = '{"test": "value"} // This is a comment'
            $result = $json | Remove-JsonComments
            $result | Should -Not -Match "//"
            $result | Should -Match '"test"'
        }

        It "Should handle complex JSON with comments via pipeline" {
            $json = @"
{
    "EntraRoles": {
        "Policies": {
            "Global Administrator": { // Admin role
                "ActivationDuration": "PT8H"
            }
        }
    }
}
"@
            $result = $json | Remove-JsonComments
            $result | Should -Not -Match "//"
            $result | Should -Match "Global Administrator"
            $result | Should -Match "PT8H"
        }

        It "Should preserve JSON structure when using pipeline" {
            $json = '{"test": "value", "nested": {"prop": "val"}} // comment'
            $result = $json | Remove-JsonComments
            $parsed = $result | ConvertFrom-Json
            $parsed.test | Should -Be "value"
            $parsed.nested.prop | Should -Be "val"
        }
    }

    Context "Edge cases" {
        It "Should handle JSON without comments" {
            $json = '{"test": "value", "another": "value2"}'
            $result = Remove-JsonComments -Content $json
            $result.Trim() | Should -Be $json
        }

        It "Should handle empty string" {
            $result = Remove-JsonComments -Content " "
            $result.Trim() | Should -Be ""
        }

        It "Should preserve string literals with comment-like content" {
            $json = '{"url": "https://example.com//path", "comment": "Use blocks"}'
            $result = Remove-JsonComments -Content $json
            $result | Should -Match "https://example.com//path"
            $result | Should -Match "Use blocks"
        }
    }

    Context "Integration with Get-EasyPIMConfiguration pattern" {
        It "Should work with the exact pattern used in Get-EasyPIMConfiguration" {
            $jsonString = @"
{
    "EntraRoles": { // Entra ID roles
        "Policies": {
            "Global Administrator": {
                "ActivationDuration": "PT8H" // 8 hours
            }
        }
    }
}
"@
            # This is the exact pattern from Get-EasyPIMConfiguration line 272
            $result = $jsonString | Remove-JsonComments
            $result | Should -Not -Match "//"
            $parsed = $result | ConvertFrom-Json
            $parsed.EntraRoles.Policies.'Global Administrator'.ActivationDuration | Should -Be "PT8H"
        }
    }
}
