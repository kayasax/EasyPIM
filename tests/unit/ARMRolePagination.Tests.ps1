BeforeAll {
    . "$PSScriptRoot\..\..\EasyPIM\internal\functions\Get-AllPolicies.ps1"
    . "$PSScriptRoot\..\..\EasyPIM\internal\functions\Invoke-ARM.ps1"
    . "$PSScriptRoot\..\..\EasyPIM\internal\functions\Get-PIMAzureEnvironmentEndpoint.ps1"
    function New-OfflineRolePage($Names, $NextLink) {
        @{
            value = @($Names | ForEach-Object { @{ properties = @{ roleName = $_ } } })
            nextLink = $NextLink
        }
    }
}

Describe 'ARM role enumeration pagination (#277)' {
    BeforeEach {
        $script:armHost = 'https://management.usgovcloudapi.net/'
        $script:scope = 'subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/offline'
        $script:first = "$($script:armHost)$script:scope/providers/Microsoft.Authorization/roleDefinitions?`$select=roleName&api-version=2022-04-01"
        $script:next = "$($script:armHost)next?api-version=2022-04-01&`$skiptoken=A%2BB%2F%3D&`$select=roleName"
        $script:calls = [System.Collections.Generic.List[string]]::new()
        Mock Get-PIMAzureEnvironmentEndpoint { $script:armHost }
        Mock Invoke-ARM {
            $script:calls.Add($restURI)
            if ($restURI -eq $script:first) { New-OfflineRolePage @('Owner', 'Reader') $script:next }
            elseif ($restURI -eq $script:next) { New-OfflineRolePage @('Contributor') }
            else { throw 'Unexpected offline URL' }
        }
    }

    It 'Returns all names in order and preserves exact URLs and request context' {
        $roles = @(Get-AllPolicies -scope $script:scope -TenantId 'offline-tenant')
        ($roles -join ',') | Should -Be 'Owner,Reader,Contributor'
        $roles[0] | Should -BeOfType ([string])
        ($script:calls -join '|') | Should -Be "$script:first|$script:next"
        Should -Invoke Invoke-ARM -Times 2 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and -not $Body -and $TenantId -eq 'offline-tenant' -and
            $SubscriptionId -eq '11111111-1111-1111-1111-111111111111' -and $ErrorAction -eq 'Stop'
        }
    }

    It 'Continues through an empty page' {
        Mock Invoke-ARM {
            if ($restURI -eq $script:first) { New-OfflineRolePage @() $script:next }
            else { New-OfflineRolePage @('Reader') }
        }
        @(Get-AllPolicies -scope $script:scope) | Should -Be @('Reader')
        Should -Invoke Invoke-ARM -Times 2 -Exactly
    }

    It 'Preserves single-page results with <Count> roles' -TestCases @(
        @{ Count = 0 }, @{ Count = 1 }, @{ Count = 2 }
    ) {
        param($Count)
        $script:names = @('Owner', 'Reader') | Select-Object -First $Count
        Mock Invoke-ARM { @{ value = @(New-OfflineRolePage $script:names).value } }
        $result = @(Get-AllPolicies -scope $script:scope)
        $result.Count | Should -Be $Count
        ($result -join ',') | Should -Be ($script:names -join ',')
        Should -Invoke Invoke-ARM -Times 1 -Exactly
    }

    It 'Keeps tenant-only context for non-subscription scopes' {
        Mock Invoke-ARM { New-OfflineRolePage @('Reader') $null }
        Get-AllPolicies -scope '/providers/Microsoft.Management/managementGroups/offline' -TenantId 'offline-tenant'
        Should -Invoke Invoke-ARM -Times 1 -Exactly -ParameterFilter {
            -not $SubscriptionId -and $TenantId -eq 'offline-tenant'
        }
    }

    It 'Fails without streaming partial names when a later page errors' {
        Mock Invoke-ARM {
            if ($restURI -eq $script:first) { New-OfflineRolePage @('Owner') $script:next }
            else { throw 'later page failed' }
        }
        $emitted = [System.Collections.Generic.List[string]]::new()
        { Get-AllPolicies -scope $script:scope | ForEach-Object { $emitted.Add($_) } } |
            Should -Throw '*later page failed*'
        $emitted.Count | Should -Be 0
    }

    It 'Rejects unsafe continuation <Link> before another authenticated call' -TestCases @(
        @{ Link = 'https://untrusted.invalid/roles' }
        @{ Link = 'http://management.usgovcloudapi.net/roles' }
        @{ Link = 'https://management.usgovcloudapi.net:444/roles' }
        @{ Link = 'https://user@management.usgovcloudapi.net/roles' }
        @{ Link = 'https://management.usgovcloudapi.net/roles#fragment' }
        @{ Link = '/relative/roles' }
        @{ Link = 'not a URL' }
    ) {
        param($Link)
        $script:next = $Link
        { Get-AllPolicies -scope $script:scope } | Should -Throw '*origin mismatch*'
        Should -Invoke Invoke-ARM -Times 1 -Exactly
    }

    It 'Stops a repeated continuation rather than returning duplicates' {
        Mock Invoke-ARM { New-OfflineRolePage @('Reader') $script:next }
        { Get-AllPolicies -scope $script:scope } | Should -Throw '*repeated ARM continuation*'
        Should -Invoke Invoke-ARM -Times 2 -Exactly
    }

    It 'Stops a cycle back to the first page' {
        Mock Invoke-ARM {
            if ($restURI -eq $script:first) { New-OfflineRolePage @('Owner') $script:next }
            else { New-OfflineRolePage @('Reader') $script:first }
        }
        { Get-AllPolicies -scope $script:scope } | Should -Throw '*repeated ARM continuation*'
        Should -Invoke Invoke-ARM -Times 2 -Exactly
    }
}

Describe 'Role pagination through the real shared ARM retry helper' {
    BeforeEach {
        $savedToken = $env:AZURE_ACCESS_TOKEN
        $env:AZURE_ACCESS_TOKEN = 'offline-token'
        $script:next = 'https://management.chinacloudapi.cn/next?api-version=2022-04-01&$skiptoken=A%2BB%3D'
        $script:attempts = 0
        $script:failure = [Exception]::new('offline throttling')
        $script:failure | Add-Member NoteProperty Response ([pscustomobject]@{
            StatusCode = 429; Headers = @{ 'Retry-After' = '0' }
        })
        Mock Get-PIMAzureEnvironmentEndpoint { 'https://management.chinacloudapi.cn/' }
        Mock Start-Sleep {}
        Mock Invoke-RestMethod {
            if ($Uri -ne $script:next) { return New-OfflineRolePage @('Owner') $script:next }
            $script:attempts++
            if ($script:attempts -eq 1) { throw $script:failure }
            New-OfflineRolePage @('Reader')
        }
    }
    AfterEach { $env:AZURE_ACCESS_TOKEN = $savedToken }

    It 'Retries a later-page 429 using the unchanged continuation query' {
        (@(Get-AllPolicies -scope 'providers/Microsoft.Management/managementGroups/offline') -join ',') |
            Should -Be 'Owner,Reader'
        Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
            $Uri -ceq $script:next -and $Method -eq 'GET' -and $ErrorAction -eq 'Stop'
        }
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }

    It 'Emits no partial results when a later page exhausts shared retries' {
        Mock Invoke-RestMethod {
            if ($Uri -ne $script:next) { return New-OfflineRolePage @('Owner') $script:next }
            throw $script:failure
        }
        $emitted = [System.Collections.Generic.List[string]]::new()
        { Get-AllPolicies -scope 'providers/Microsoft.Management/managementGroups/offline' |
            ForEach-Object { $emitted.Add($_) } } | Should -Throw '*offline throttling*'
        $emitted.Count | Should -Be 0
        Should -Invoke Invoke-RestMethod -Times 7 -Exactly
        Should -Invoke Start-Sleep -Times 5 -Exactly
    }
}
