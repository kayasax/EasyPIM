# 🔧 EasyPIM KeyVault Bridge Function
# This function bridges the gap between KeyVault configs and the current published module
# Until the KeyVault support is officially published

function Test-PIMPolicyDriftFromKeyVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [switch]$FailOnDrift,

        [switch]$PassThru
    )

    Write-Host "🔄 Retrieving configuration from KeyVault..." -ForegroundColor Cyan

    try {
        # Get secret from KeyVault
        $secretValue = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction Stop

        if ([string]::IsNullOrEmpty($secretValue)) {
            throw "KeyVault secret '$SecretName' is empty or null"
        }

        Write-Host "✅ Retrieved config from KeyVault ($($secretValue.Length) characters)" -ForegroundColor Green

        # Create temporary file
        $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
        $secretValue | Out-File -FilePath $tempPath -Encoding UTF8 -NoNewline

        Write-Host "📝 Created temporary config file: $tempPath" -ForegroundColor Gray

        # Apply telemetry hotpatch
        if (Test-Path "$PSScriptRoot\simple-telemetry-hotpatch.ps1") {
            Write-Host "🔧 Applying telemetry hotpatch..." -ForegroundColor Yellow
            . "$PSScriptRoot\simple-telemetry-hotpatch.ps1"
        }

        # Build parameters for the actual function
        $testParams = @{
            TenantId = $TenantId
            ConfigPath = $tempPath
        }

        if ($SubscriptionId) {
            $testParams.SubscriptionId = $SubscriptionId
        }

        if ($FailOnDrift) {
            $testParams.FailOnDrift = $true
        }

        if ($PassThru) {
            $testParams.PassThru = $true
        }

        Write-Host "🚀 Running Test-PIMPolicyDrift..." -ForegroundColor Green

        # Call the actual function
        $result = Test-PIMPolicyDrift @testParams

        # Clean up temp file
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        Write-Host "🧹 Cleaned up temporary file" -ForegroundColor Gray

        return $result

    } catch {
        # Clean up temp file if it exists
        if (Test-Path $tempPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host "❌ Failed to test PIM policy drift from KeyVault: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Invoke-EasyPIMOrchestratorFromKeyVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [switch]$WhatIf
    )

    Write-Host "🔄 Retrieving configuration from KeyVault..." -ForegroundColor Cyan

    try {
        # Get secret from KeyVault
        $secretValue = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction Stop

        if ([string]::IsNullOrEmpty($secretValue)) {
            throw "KeyVault secret '$SecretName' is empty or null"
        }

        Write-Host "✅ Retrieved config from KeyVault ($($secretValue.Length) characters)" -ForegroundColor Green

        # Create temporary file
        $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
        $secretValue | Out-File -FilePath $tempPath -Encoding UTF8 -NoNewline

        Write-Host "📝 Created temporary config file: $tempPath" -ForegroundColor Gray

        # Apply telemetry hotpatch
        if (Test-Path "$PSScriptRoot\simple-telemetry-hotpatch.ps1") {
            Write-Host "🔧 Applying telemetry hotpatch..." -ForegroundColor Yellow
            . "$PSScriptRoot\simple-telemetry-hotpatch.ps1"
        }

        # Build parameters for the actual function
        $orchestratorParams = @{
            TenantId = $TenantId
            ConfigPath = $tempPath
        }

        if ($SubscriptionId) {
            $orchestratorParams.SubscriptionId = $SubscriptionId
        }

        if ($WhatIf) {
            $orchestratorParams.WhatIf = $true
        }

        Write-Host "🚀 Running Invoke-EasyPIMOrchestrator..." -ForegroundColor Green

        # Call the actual function
        $result = Invoke-EasyPIMOrchestrator @orchestratorParams

        # Clean up temp file
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        Write-Host "🧹 Cleaned up temporary file" -ForegroundColor Gray

        return $result

    } catch {
        # Clean up temp file if it exists
        if (Test-Path $tempPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host "❌ Failed to run orchestrator from KeyVault: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

Write-Host "✅ KeyVault bridge functions loaded!" -ForegroundColor Green
Write-Host "📋 Available functions:" -ForegroundColor Cyan
Write-Host "   - Test-PIMPolicyDriftFromKeyVault" -ForegroundColor White
Write-Host "   - Invoke-EasyPIMOrchestratorFromKeyVault" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Example usage:" -ForegroundColor Cyan
Write-Host "   Test-PIMPolicyDriftFromKeyVault -TenantId 'your-tenant' -KeyVaultName 'kv-easypim-8368' -SecretName 'easypim-config-json'" -ForegroundColor White
