BeforeAll {
    . "$PSScriptRoot\..\..\EasyPIM\internal\functions\Invoke-ARM.ps1"
    function az { }
    Add-Type -AssemblyName System.Net.Http
    if (-not ('OfflineArmWebResponse' -as [type])) {
        Add-Type @'
public class OfflineArmWebResponse : System.Net.WebResponse {
    public System.Net.HttpStatusCode StatusCode { get; set; }
    private System.Net.WebHeaderCollection headers = new System.Net.WebHeaderCollection();
    public override System.Net.WebHeaderCollection Headers { get { return headers; } }
}
'@
    }
    function New-OfflineArmError($Status = 429, $Header = '3', $Shape = 'Dictionary', $Details = $true) {
        if ($Shape -eq 'HttpResponse') {
            $response = [System.Net.Http.HttpResponseMessage]::new(
                [Enum]::ToObject([System.Net.HttpStatusCode], $Status))
            if ($null -ne $Header) { $null = $response.Headers.TryAddWithoutValidation('Retry-After', [string[]]@($Header)) }
            $response.Content = [System.Net.Http.StringContent]::new('original ARM response body')
        } elseif ($Shape -eq 'WebException') {
            $response = New-Object OfflineArmWebResponse
            $response.StatusCode = [Enum]::ToObject([System.Net.HttpStatusCode], $Status)
            if ($null -ne $Header) { $response.Headers['Retry-After'] = $Header }
        } else {
            $response = [pscustomobject]@{ StatusCode = $Status; Headers = @{ 'Retry-After' = $Header } }
        }
        if ($Shape -eq 'WebException') {
            $exception = [System.Net.WebException]::new('original ARM failure', $null,
                [System.Net.WebExceptionStatus]::ProtocolError, $response)
        } elseif ($Shape -eq 'HttpResponse' -and $PSVersionTable.PSVersion.Major -ge 7) {
            $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('original ARM failure', $response)
        } else {
            $exception = [Exception]::new('original ARM failure')
            $exception | Add-Member NoteProperty Response $response
        }
        $record = [System.Management.Automation.ErrorRecord]::new($exception, 'Offline429',
            [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
        if ($Details) { $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('original ARM response body') }
        return $record
    }
}

Describe 'Core shared ARM GET throttling (#269)' {
    BeforeEach {
        $savedToken = $env:AZURE_ACCESS_TOKEN
        $env:AZURE_ACCESS_TOKEN = 'offline-token'
        $script:attempts = 0
        $script:failure = New-OfflineArmError
        Mock Start-Sleep {}
        Mock Get-Random { 0 }
        Mock Get-Date { [datetime]'2026-09-26T12:00:00Z' }
        Mock Invoke-RestMethod {
            $script:attempts++
            if ($script:attempts -eq 1) { throw $script:failure }
            return @{ value = @('recovered') }
        }
    }
    AfterEach { $env:AZURE_ACCESS_TOKEN = $savedToken }

    It 'Recovers and preserves request arguments for <Shape> headers' -TestCases @(
        @{ Shape = 'Dictionary' }, @{ Shape = 'WebException' }, @{ Shape = 'HttpResponse' }
    ) {
        param($Shape)
        $script:failure = New-OfflineArmError -Shape $Shape
        (Invoke-ARM 'https://example.invalid/roles?api-version=test' GET -body '{}' -ErrorAction Stop).value |
            Should -Be 'recovered'
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
            $Uri -eq 'https://example.invalid/roles?api-version=test' -and $Method -eq 'GET' -and
            $Body -eq '{}' -and $Headers['Content-Type'] -eq 'application/json' -and $ErrorAction -eq 'Stop'
        }
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 3000 }
    }

    It 'Honors header <Label>' -TestCases @(
        @{ Label = 'array'; Header = @('2','4'); Milliseconds = 4000 }
        @{ Label = 'HTTP date'; Header = 'Sat, 26 Sep 2026 12:00:07 GMT'; Milliseconds = 7000 }
        @{ Label = 'past date'; Header = 'Sat, 26 Sep 2026 11:00:00 GMT'; Milliseconds = 0 }
        @{ Label = 'zero'; Header = '0'; Milliseconds = 0 }
        @{ Label = 'missing'; Header = $null; Milliseconds = 2000 }
        @{ Label = 'invalid'; Header = 'invalid'; Milliseconds = 2000 }
        @{ Label = 'negative'; Header = '-1'; Milliseconds = 2000 }
    ) {
        param($Header, $Milliseconds)
        $expectedDelay = $Milliseconds
        $script:failure = New-OfflineArmError -Header $Header
        $null = Invoke-ARM 'https://example.invalid/roles' GET
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq $expectedDelay } -Scope It
    }

    It 'Stops after five retries and keeps diagnostic body with ErrorAction Stop' {
        $script:failure = New-OfflineArmError -Header '0'
        Mock Invoke-RestMethod { throw $script:failure }
        { Invoke-ARM 'https://example.invalid/roles' GET -ErrorAction Stop } |
            Should -Throw '*original ARM failure*original ARM response body*'
        Should -Invoke Invoke-RestMethod -Times 6 -Exactly
        Should -Invoke Start-Sleep -Times 5 -Exactly
    }

    It 'Does not shorten a server delay exceeding remaining budget (<Header>)' -TestCases @(
        @{ Header = '61'; Calls = 1; Sleeps = 0 }
        @{ Header = '40'; Calls = 2; Sleeps = 1 }
        @{ Header = '30'; Calls = 3; Sleeps = 2 }
        @{ Header = '999999999999999999999999999999999'; Calls = 1; Sleeps = 0 }
    ) {
        param($Header, $Calls, $Sleeps)
        $script:failure = New-OfflineArmError -Header $Header
        Mock Invoke-RestMethod { throw $script:failure }
        { Invoke-ARM 'https://example.invalid/roles' GET -ErrorAction Stop } | Should -Throw '*original ARM failure*'
        Should -Invoke Invoke-RestMethod -Times $Calls -Exactly
        Should -Invoke Start-Sleep -Times $Sleeps -Exactly
    }

    It 'Uses bounded exponential jitter without a header' {
        $script:failure = New-OfflineArmError -Header $null
        $script:delays = @()
        Mock Get-Random { 500 }
        Mock Start-Sleep { $script:delays += $Milliseconds }
        Mock Invoke-RestMethod { throw $script:failure }
        { Invoke-ARM 'https://example.invalid/roles' GET -ErrorAction Stop } | Should -Throw
        ($script:delays -join ',') | Should -Be '2500,4500,8500,16500'
        Should -Invoke Invoke-RestMethod -Times 5 -Exactly
    }

    It 'Never retries <Method> with status <Status>' -TestCases @(
        @{ Method = 'POST'; Status = 429 }, @{ Method = 'PUT'; Status = 429 }
        @{ Method = 'PATCH'; Status = 429 }, @{ Method = 'DELETE'; Status = 429 }
        @{ Method = 'GET'; Status = 400 }, @{ Method = 'GET'; Status = 401 }
        @{ Method = 'GET'; Status = 403 }, @{ Method = 'GET'; Status = 404 }
        @{ Method = 'GET'; Status = 503 }
    ) {
        param($Method, $Status)
        $script:failure = New-OfflineArmError -Status $Status
        { Invoke-ARM 'https://example.invalid/roles' $Method -ErrorAction Stop } | Should -Throw
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'Preserves PS7 content when ErrorDetails is absent' {
        $script:failure = New-OfflineArmError -Shape HttpResponse -Header '61' -Details $false
        { Invoke-ARM 'https://example.invalid/roles' GET -ErrorAction Stop } |
            Should -Throw '*original ARM failure*original ARM response body*'
    }

    It 'Acquires the scoped token once, outside the retry loop' {
        Mock Get-AzContext {
            @{ Subscription = @{ Id = 'offline-subscription' }; Tenant = @{ Id = 'offline-tenant' } }
        }
        Mock Get-AzAccessToken { @{ Token = 'offline-scoped-token' } }
        $null = Invoke-ARM 'https://example.invalid/roles' GET -SubscriptionId 'offline-subscription'
        Should -Invoke Get-AzContext -Times 1 -Exactly
        Should -Invoke Get-AzAccessToken -Times 1 -Exactly -ParameterFilter { $TenantId -eq 'offline-tenant' }
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly
    }

    It 'Does not retry transport failures without an HTTP response' {
        Mock Invoke-RestMethod { throw 'offline transport failure' }
        { Invoke-ARM 'https://example.invalid/roles' GET -ErrorAction Stop } | Should -Throw '*offline transport failure*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'Keeps OAuth acquisition outside retries and preserves the ARM body' {
        $names = @('AZURE_ACCESS_TOKEN', 'ARM_ACCESS_TOKEN', 'AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_CLIENT_SECRET')
        $saved = @{}
        foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        try {
            $env:AZURE_ACCESS_TOKEN = $null
            $env:ARM_ACCESS_TOKEN = $null
            $env:AZURE_CLIENT_ID = 'offline-client'
            $env:AZURE_TENANT_ID = 'offline-tenant'
            $env:AZURE_CLIENT_SECRET = 'offline-secret'
            Mock az {}
            Mock Get-AzContext { $null }
            Mock Invoke-RestMethod { @{ access_token = 'offline-oauth-token' } } -ParameterFilter {
                $Uri -like 'https://login.microsoftonline.com/*'
            }
            $null = Invoke-ARM 'https://example.invalid/roles' GET -body '{"preserved":true}'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -like 'https://login.microsoftonline.com/*' -and $Method -eq 'POST'
            }
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
                $Uri -eq 'https://example.invalid/roles' -and $Body -eq '{"preserved":true}'
            }
        } finally {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }

    It 'Rethrows the original error record on exhaustion when diagnostics are nonterminating' {
        $script:failure = New-OfflineArmError -Header '61'
        Mock Write-Error {}
        try {
            Invoke-ARM 'https://example.invalid/roles' GET
            throw 'Expected failure'
        } catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'Offline429*'
            $_.Exception.Response.StatusCode | Should -Be 429
            $_.ErrorDetails.Message | Should -Be 'original ARM response body'
        }
    }
}
