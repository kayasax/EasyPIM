<#
.SYNOPSIS
Test Azure Resource Manager API authentication and connectivity

.DESCRIPTION
Validates ARM API access for OIDC and traditional authentication scenarios,
providing detailed diagnostics for troubleshooting.

.PARAMETER SubscriptionId
Azure subscription ID to test ARM access against

.PARAMETER Verbose
Enable verbose output for detailed authentication diagnostics

.EXAMPLE
Test-ARMAuthentication -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
Test-ARMAuthentication -SubscriptionId $env:AZURE_SUBSCRIPTION_ID -Verbose

.NOTES
Author: EasyPIM Team
This function helps diagnose OIDC authentication issues with ARM API calls
#>
function Test-ARMAuthentication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId
    )

    try {
        Write-Verbose "Starting ARM authentication test..."

        # Use subscription from environment if not provided
        if (-not $SubscriptionId) {
            $SubscriptionId = $env:AZURE_SUBSCRIPTION_ID
            if (-not $SubscriptionId) {
                $azContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($azContext -and $azContext.Subscription) {
                    $SubscriptionId = $azContext.Subscription.Id
                }
            }
        }

        if (-not $SubscriptionId) {
            Write-Warning "No subscription ID provided and none found in context/environment"
            $testUri = "https://management.azure.com/tenants?api-version=2020-01-01"
            Write-Verbose "Using tenant list endpoint for basic ARM connectivity test"
        } else {
            $testUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups?api-version=2021-04-01"
            Write-Verbose "Testing ARM access for subscription: $SubscriptionId"
        }

        # Test ARM connectivity using our enhanced Invoke-ARM function
        Write-Host "🔍 Testing ARM API authentication..." -ForegroundColor Cyan

        $response = Invoke-ARM -restURI $testUri -method "GET" -Verbose:$VerbosePreference

        if ($response) {
            Write-Host "✅ ARM API authentication successful!" -ForegroundColor Green
            if ($SubscriptionId) {
                $resourceGroupCount = $response.value.Count
                Write-Host "  Found $resourceGroupCount resource groups in subscription" -ForegroundColor Gray
            } else {
                $tenantCount = $response.value.Count
                Write-Host "  ARM tenant access confirmed ($tenantCount tenants accessible)" -ForegroundColor Gray
            }
            return $true
        } else {
            Write-Host "⚠️ ARM API call succeeded but returned no data" -ForegroundColor Yellow
            return $true
        }

    } catch {
        Write-Host "❌ ARM API authentication failed!" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

        # Provide GitHub Actions OIDC troubleshooting guidance
        Write-Host ""
        Write-Host "🔧 GitHub Actions OIDC Troubleshooting Guide:" -ForegroundColor Yellow
        Write-Host "1. Recommended: Use azure/login@v2 action with OIDC in your workflow:" -ForegroundColor Gray
        Write-Host "   - permissions: id-token: write" -ForegroundColor Gray
        Write-Host "   - uses: azure/login@v2 with client-id, tenant-id, subscription-id secrets" -ForegroundColor Gray
        Write-Host "   - enable-AzPSSession: true" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Alternative: Set AZURE_ACCESS_TOKEN environment variable with valid ARM token" -ForegroundColor Gray
        Write-Host "3. Verify federated identity credentials are configured in Azure:" -ForegroundColor Gray
        Write-Host "   - Issuer: https://token.actions.githubusercontent.com" -ForegroundColor Gray
        Write-Host "   - Subject: repo:owner/repo:environment:production" -ForegroundColor Gray
        Write-Host "   - Audience: api://AzureADTokenExchange" -ForegroundColor Gray
        Write-Host ""
        Write-Host "4. Check Azure PowerShell context is available after azure/login@v2" -ForegroundColor Gray

        Write-Host ""
        Write-Host "Environment Variables:" -ForegroundColor Yellow
        Write-Host "  AZURE_CLIENT_ID: $($null -ne $env:AZURE_CLIENT_ID)" -ForegroundColor Gray
        Write-Host "  AZURE_TENANT_ID: $($null -ne $env:AZURE_TENANT_ID)" -ForegroundColor Gray
        Write-Host "  AZURE_ACCESS_TOKEN: $($null -ne $env:AZURE_ACCESS_TOKEN)" -ForegroundColor Gray
        Write-Host "  AZURE_SUBSCRIPTION_ID: $($null -ne $env:AZURE_SUBSCRIPTION_ID)" -ForegroundColor Gray
        Write-Host "  Azure PowerShell Context: $(if (Get-AzContext -ErrorAction SilentlyContinue) { "Available" } else { "Not Available" })" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "📖 Official Documentation: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect" -ForegroundColor Cyan

        return $false
    }
}
