$ModulePath = Join-Path $PSScriptRoot "..\..\EasyPIM\EasyPIM.psd1"
Import-Module $ModulePath -Force

Describe 'Get-PIMAzureResourcePolicy' {
    It 'returns the correct policy' {
        # Arrange
        $tenantID = '8d4fd732-58aa-4643-8cae-974854a66a2d'
        $subscriptionID = 'eedcaa84-3756-4da9-bf87-40068c3dd2a2'

        # Mock Invoke-ARM to return appropriate responses based on the URI
        Mock -ModuleName EasyPIM Invoke-ARM {
            param($restURI)
            if ($restURI -match "roleDefinitions") {
                return [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{
                            id = "/subscriptions/$subscriptionID/providers/Microsoft.Authorization/roleDefinitions/Pester"
                        }
                    )
                }
            }
            if ($restURI -match "roleManagementPolicyAssignments") {
                return [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{
                            properties = [PSCustomObject]@{
                                policyId = "/subscriptions/$subscriptionID/providers/Microsoft.Authorization/roleManagementPolicies/Policy123"
                            }
                        }
                    )
                }
            }
            # Default or specific policy call
            return [PSCustomObject]@{
                properties = [PSCustomObject]@{
                    rules = @(
                        [PSCustomObject]@{
                            id = "Expiration_EndUser_Assignment"
                            maximumDuration = "PT8H"
                            properties = [PSCustomObject]@{ maximumDuration = "PT8H" }
                        },
                        [PSCustomObject]@{
                            id = "Enablement_EndUser_Assignment"
                            enabledRules = @("Justification")
                            properties = [PSCustomObject]@{ enabledRules = @("Justification") }
                        }
                    )
                }
            }
        }

        # Mock Get-AzRoleDefinition to return the role name
        Mock -ModuleName EasyPIM Get-AzRoleDefinition {
            return [PSCustomObject]@{
                Name = "Pester"
                Id = "Pester"
            }
        }

        # Act
        $result = Get-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionID -rolename "Pester"

        # Assert
        # Here you should add the logic to check if the correct policy was returned
        # This will depend on how your function works and what it returns
        $result.Rolename | Should -Be "Pester"
        $result.ActivationDuration| Should -Be "PT8H"
        $result.EnablementRules | Should -Be "Justification"
    }
}
