<#
.SYNOPSIS
    Sends anonymous telemetry events to PostHog for EasyPIM usage analytics using a config object

.DESCRIPTION
    Collects and sends privacy-protected usage statistics to help improve EasyPIM.
    Only operates if ALLOW_TELEMETRY is enabled in configuration. Never fails
    the main operation - all telemetry errors are non-blocking.

    This function accepts a config object directly instead of requiring a file path,
    making it suitable for KeyVault-based configurations.

.PARAMETER EventName
    The name of the telemetry event (e.g., "orchestrator_execution")

.PARAMETER Properties
    Hashtable of event properties to send

.PARAMETER Config
    Configuration object containing telemetry settings

.EXAMPLE
    $props = @{ execution_mode = "WhatIf"; success = $true }
    Send-TelemetryEventFromConfig -EventName "orchestrator_execution" -Properties $props -Config $configObject

.NOTES
    Author: Loïc MICHEL
    Privacy: Encrypts tenant ID, collects no PII, opt-in only
    Documentation: https://github.com/kayasax/EasyPIM/blob/main/TELEMETRY.md
#>
function Send-TelemetryEventFromConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties,

        [Parameter(Mandatory = $true)]
        [object]$Config
    )

    try {
        Write-Verbose "🔍 [TELEMETRY] Checking telemetry configuration from config object..."
        Write-Host "🔍 [DEBUG] Send-TelemetryEventFromConfig called for event: $EventName" -ForegroundColor Yellow

        if (-not $Config) {
            Write-Verbose "❌ [TELEMETRY] No configuration object provided - skipping telemetry"
            Write-Host "❌ [DEBUG] No config object provided to telemetry function" -ForegroundColor Red
            return
        }

        Write-Host "🔍 [DEBUG] Config object received, checking TelemetrySettings..." -ForegroundColor Yellow
        Write-Host "🔍 [DEBUG] Config.TelemetrySettings exists: $($null -ne $Config.TelemetrySettings)" -ForegroundColor Yellow
        if ($Config.TelemetrySettings) {
            Write-Host "🔍 [DEBUG] Config.TelemetrySettings.ALLOW_TELEMETRY value: $($Config.TelemetrySettings.ALLOW_TELEMETRY)" -ForegroundColor Yellow
        }

        # Check if telemetry is enabled (default to false - opt-in only)
        $TelemetryEnabled = $false
        if ($Config.TelemetrySettings -and $Config.TelemetrySettings.ALLOW_TELEMETRY) {
            $TelemetryEnabled = $Config.TelemetrySettings.ALLOW_TELEMETRY
        }

        if (-not $TelemetryEnabled) {
            Write-Verbose "❌ [TELEMETRY] Telemetry disabled in configuration - skipping event: $EventName"
            Write-Host "❌ [DEBUG] Telemetry disabled or not configured - skipping event: $EventName" -ForegroundColor Red
            return
        }

        Write-Verbose "✅ [TELEMETRY] Telemetry enabled - preparing event: $EventName"
        Write-Host "✅ [DEBUG] Telemetry enabled - proceeding with event: $EventName" -ForegroundColor Green

        # Get Microsoft Graph context for tenant information
        $Context = $null
        try {
            $Context = Get-MgContext -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "No Microsoft Graph context available for telemetry"
        }

        if (-not $Context -or -not $Context.TenantId) {
            Write-Verbose "No tenant context available - skipping telemetry"
            return
        }

        # Create privacy-protected identifier (always encrypted)
        $TenantIdentifier = $null
        try {
            $TenantIdentifier = Get-TelemetryIdentifier -TenantId $Context.TenantId
        }
        catch {
            # Create a fallback identifier if the function doesn't exist
            Write-Host "🔧 [DEBUG] Creating fallback tenant identifier" -ForegroundColor Yellow
            $TenantIdentifier = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Context.TenantId)) | ForEach-Object { $_.ToString("x2") } | Join-String
        }
        
        if (-not $TenantIdentifier) {
            Write-Verbose "Failed to create telemetry identifier - skipping event"
            Write-Host "❌ [DEBUG] Telemetry identifier is null" -ForegroundColor Red
            return
        }

        Write-Host "✅ [DEBUG] Telemetry identifier created successfully" -ForegroundColor Green

        # Enhance properties with system information
        $EnhancedProperties = $Properties.Clone()
        $EnhancedProperties.module_version = "1.1.9-telemetry-fixed"
        $EnhancedProperties.powershell_version = $PSVersionTable.PSVersion.ToString()
        $EnhancedProperties.os_version = Get-TelemetryOSVersion
        $EnhancedProperties.timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $EnhancedProperties.session_id = Get-TelemetrySessionId
        # Add tenant identifier as property for easier dashboard filtering
        $EnhancedProperties.tenant_id = $TenantIdentifier

        # Send to PostHog (non-blocking)
        Send-PostHogEvent -DistinctId $TenantIdentifier -EventName $EventName -Properties $EnhancedProperties

        Write-Verbose "Telemetry event sent successfully: $EventName"
        Write-Host "✅ [DEBUG] Telemetry event sent successfully: $EventName" -ForegroundColor Green

    }
    catch {
        # Telemetry failures should never break the main operation
        Write-Verbose "Telemetry failed (non-blocking): $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Sends event data to PostHog analytics platform

.DESCRIPTION
    Internal function to transmit telemetry data to PostHog.
    Uses hardcoded project key and security settings.

.PARAMETER DistinctId
    Privacy-protected tenant identifier

.PARAMETER EventName
    Name of the event to track

.PARAMETER Properties
    Event properties hashtable
#>
function Send-PostHogEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistinctId,

        [Parameter(Mandatory = $true)]
        [string]$EventName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties
    )

    # PostHog configuration (hardcoded for security and simplicity)
    $PostHogProjectKey = "phc_witsM6gj8k6GOor3RUBiN7vUPId11R2LMShF8lTUcBD"
    $PostHogApiUrl = "https://eu.posthog.com/capture/"

    # Prepare event payload
    $EventData = @{
        api_key = $PostHogProjectKey
        event = $EventName
        properties = $Properties
        distinct_id = $DistinctId
        timestamp = $Properties.timestamp
    }

    $Body = $EventData | ConvertTo-Json -Depth 10 -Compress

    try {
        # Send with short timeout to avoid blocking main operations
        $Response = Invoke-RestMethod -Uri $PostHogApiUrl -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
        Write-Verbose "PostHog API responded successfully. Status: $(if($Response.status) { $Response.status } else { 'OK' })"
        Write-Host "✅ [DEBUG] PostHog API call succeeded" -ForegroundColor Green
    }
    catch {
        Write-Verbose "PostHog API call failed: $($_.Exception.Message)"
        Write-Host "❌ [DEBUG] PostHog API call failed: $($_.Exception.Message)" -ForegroundColor Red
        # Don't throw - telemetry failures should not affect main operations
    }
}

<#
.SYNOPSIS
    Gets the operating system version for telemetry

.DESCRIPTION
    Determines the OS version in a privacy-safe way for telemetry purposes

.OUTPUTS
    String representing the OS version category
#>
function Get-TelemetryOSVersion {
    try {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            $WinVersion = [System.Environment]::OSVersion.Version
            if ($WinVersion.Build -ge 22000) {
                return "Windows_11"
            }
            elseif ($WinVersion.Major -eq 10) {
                return "Windows_10"
            }
            else {
                return "Windows_Legacy"
            }
        }
        elseif ($IsLinux) {
            return "Linux"
        }
        elseif ($IsMacOS) {
            return "macOS"
        }
        else {
            return "Unknown"
        }
    }
    catch {
        return "Unknown"
    }
}

<#
.SYNOPSIS
    Gets or creates a session-specific identifier for telemetry

.DESCRIPTION
    Generates a unique session ID for correlating telemetry events
    within the same PowerShell session

.OUTPUTS
    String GUID representing the current session
#>
function Get-TelemetrySessionId {
    # Generate or retrieve session-specific GUID
    # Note: Global variable is intentionally used for session persistence across function calls
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Session ID needs to persist across telemetry calls')]
    param()

    if (-not $Global:EasyPIMTelemetrySessionId) {
        $Global:EasyPIMTelemetrySessionId = [System.Guid]::NewGuid().ToString()
        Write-Verbose "Generated new telemetry session ID: $Global:EasyPIMTelemetrySessionId"
    }
    return $Global:EasyPIMTelemetrySessionId
}
