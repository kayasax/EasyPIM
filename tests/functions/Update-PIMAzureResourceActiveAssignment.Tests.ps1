$ModulePath = Join-Path $PSScriptRoot "..\..\EasyPIM\EasyPIM.psd1"
Import-Module $ModulePath -Force

Describe "Update-PIMAzureResourceActiveAssignment - AdminExtend" -Tag 'Unit' {

    BeforeEach {
        $script:capturedBody = $null
        $script:capturedUri  = $null

        Mock -ModuleName EasyPIM Get-PIMAzureEnvironmentEndpoint { return "https://management.azure.com" }
        Mock -ModuleName EasyPIM Get-AzContext { return [PSCustomObject]@{ Account = "admin@contoso.com" } }

        Mock -ModuleName EasyPIM Invoke-ARM {
            param($restURI, $method, $body)
            if ($restURI -match "roleDefinitions") {
                return [PSCustomObject]@{ value = @(
                    [PSCustomObject]@{ id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid" }
                ) }
            }
            if ($restURI -match "roleAssignmentSchedules\?") {
                return [PSCustomObject]@{ value = @(
                    [PSCustomObject]@{
                        id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignmentSchedules/sched-guid"
                        properties = [PSCustomObject]@{
                            roleDefinitionId = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid"
                            scope = "/subscriptions/sub1"
                            principalId = "11111111-1111-1111-1111-111111111111"
                        }
                    }
                ) }
            }
            if ($restURI -match "roleAssignmentScheduleRequests\?") { return [PSCustomObject]@{ value = @() } }
            $script:capturedUri  = $restURI
            $script:capturedBody = $body
            return [PSCustomObject]@{ properties = [PSCustomObject]@{} }
        }
    }

    It "Submits an AdminExtend request with the target role assignment schedule id" {
        Update-PIMAzureResourceActiveAssignment `
            -tenantID "00000000-0000-0000-0000-000000000000" -subscriptionID "sub1" `
            -rolename "Reader" -principalID "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z"

        $script:capturedUri  | Should -Match "roleAssignmentScheduleRequests/"
        $script:capturedBody | Should -Match '"requestType":\s*"AdminExtend"'
        $script:capturedBody | Should -Match '"targetRoleAssignmentScheduleId":\s*".*sched-guid"'
        $script:capturedBody | Should -Match '"type":\s*"AfterDateTime"'
    }

    It "Does not submit a request under -WhatIf" {
        Update-PIMAzureResourceActiveAssignment `
            -tenantID "00000000-0000-0000-0000-000000000000" -subscriptionID "sub1" `
            -rolename "Reader" -principalID "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z" -WhatIf

        $script:capturedBody | Should -BeNullOrEmpty
    }
}
