$ModulePath = Join-Path $PSScriptRoot "..\..\EasyPIM\EasyPIM.psd1"
Import-Module $ModulePath -Force

Describe "Update-PIMAzureResourceEligibleAssignment - AdminExtend" -Tag 'Unit' {

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
            if ($restURI -match "roleEligibilitySchedules\?") {
                return [PSCustomObject]@{ value = @(
                    [PSCustomObject]@{
                        id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleEligibilitySchedules/sched-guid"
                        properties = [PSCustomObject]@{
                            roleDefinitionId = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid"
                            scope = "/subscriptions/sub1"
                            principalId = "11111111-1111-1111-1111-111111111111"
                        }
                    }
                ) }
            }
            if ($restURI -match "roleEligibilityScheduleRequests\?") {
                # pending-check list: none in flight
                return [PSCustomObject]@{ value = @() }
            }
            # PUT the extend request
            $script:capturedUri  = $restURI
            $script:capturedBody = $body
            return [PSCustomObject]@{ properties = [PSCustomObject]@{} }
        }
    }

    It "Submits an AdminExtend request with the target schedule id and AfterDateTime end date" {
        Update-PIMAzureResourceEligibleAssignment `
            -tenantID       "00000000-0000-0000-0000-000000000000" `
            -subscriptionID "sub1" `
            -rolename       "Reader" `
            -principalID    "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z"

        $script:capturedUri  | Should -Match "roleEligibilityScheduleRequests/"
        $script:capturedBody | Should -Match '"requestType":\s*"AdminExtend"'
        $script:capturedBody | Should -Match '"targetRoleEligibilityScheduleId":\s*".*sched-guid"'
        $script:capturedBody | Should -Match '"type":\s*"AfterDateTime"'
        $script:capturedBody | Should -Match '2026-12-31T00:00:00Z'
    }

    It "Does not submit a request under -WhatIf" {
        Update-PIMAzureResourceEligibleAssignment `
            -tenantID       "00000000-0000-0000-0000-000000000000" `
            -subscriptionID "sub1" `
            -rolename       "Reader" `
            -principalID    "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z" `
            -WhatIf

        $script:capturedBody | Should -BeNullOrEmpty
    }

    It "Throws when no matching eligible schedule exists" {
        Mock -ModuleName EasyPIM Invoke-ARM {
            param($restURI, $method, $body)
            if ($restURI -match "roleDefinitions") {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid" }) }
            }
            if ($restURI -match "roleEligibilitySchedules\?") { return [PSCustomObject]@{ value = @() } }
            return [PSCustomObject]@{ value = @() }
        }

        { Update-PIMAzureResourceEligibleAssignment `
            -tenantID "00000000-0000-0000-0000-000000000000" -subscriptionID "sub1" `
            -rolename "Reader" -principalID "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z" -ErrorAction Stop } | Should -Throw
    }

    It "Skips submission when an AdminExtend request is already in flight" {
        Mock -ModuleName EasyPIM Invoke-ARM {
            param($restURI, $method, $body)
            if ($restURI -match "roleDefinitions") {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid" }) }
            }
            if ($restURI -match "roleEligibilitySchedules\?") {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{
                    id = "/subscriptions/sub1/providers/Microsoft.Authorization/roleEligibilitySchedules/sched-guid"
                    properties = [PSCustomObject]@{
                        roleDefinitionId = "/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/role-guid"
                        scope = "/subscriptions/sub1"
                        principalId = "11111111-1111-1111-1111-111111111111"
                    }
                }) }
            }
            if ($restURI -match "roleEligibilityScheduleRequests\?") {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        targetRoleEligibilityScheduleId = "/subscriptions/sub1/providers/Microsoft.Authorization/roleEligibilitySchedules/sched-guid"
                        requestType = "AdminExtend"
                        status = "PendingApproval"
                    }
                }) }
            }
            $script:capturedBody = $body
            return [PSCustomObject]@{ properties = [PSCustomObject]@{} }
        }

        Update-PIMAzureResourceEligibleAssignment `
            -tenantID "00000000-0000-0000-0000-000000000000" -subscriptionID "sub1" `
            -rolename "Reader" -principalID "11111111-1111-1111-1111-111111111111" `
            -newEndDateTime "2026-12-31T00:00:00Z" -WarningAction SilentlyContinue

        $script:capturedBody | Should -BeNullOrEmpty
    }
}
