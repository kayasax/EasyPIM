Describe 'Get-PIMAzureResourcePolicy' {
    It 'returns the correct policy' {
        # Arrange
        $tenantID = '8d4fd732-58aa-4643-8cae-974854a66a2d'
        $subscriptionID = 'eedcaa84-3756-4da9-bf87-40068c3dd2a2'

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