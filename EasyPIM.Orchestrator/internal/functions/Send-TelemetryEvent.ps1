<#
.SYNOPSIS
    Sends anonymous telemetry events to PostHog for EasyPIM usage analytics

.DESCRIPTION
    Collects and sends privacy-protected usage statistics to help improve EasyPIM.
    Only operates if ALLOW_TELEMETRY is enabled in configuration. Never fails
    the main operation - all telemetry errors are non-blocking.

.PARAMETER EventName
    The name of the telemetry event (e.g., "orchestrator_execution")

.PARAMETER Properties
    Hashtable of event properties to send

.PARAMETER ConfigPath
    Path to the configuration file to check telemetry settings

.EXAMPLE
    $props = @{ execution_mode = "WhatIf"; success = $true }
    Send-TelemetryEvent -EventName "orchestrator_execution" -Properties $props -ConfigPath "config.json"

.NOTES
    Author: Loïc MICHEL
    Privacy: Encrypts tenant ID, collects no PII, opt-in only
    Documentation: https://github.com/kayasax/EasyPIM/blob/main/TELEMETRY.md
#>
function Send-TelemetryEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    try {
        Write-Verbose "Checking telemetry configuration..."
        Write-Host "🔍 [DEBUG] Send-TelemetryEvent called for event: $EventName" -ForegroundColor Yellow

        # Load configuration to check telemetry settings
        if (-not (Test-Path $ConfigPath)) {
            Write-Verbose "Configuration file not found - skipping telemetry"
            Write-Host "❌ [DEBUG] Configuration file not found: $ConfigPath" -ForegroundColor Red
            return
        }

        $ConfigContent = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
        if (-not $ConfigContent) {
            Write-Verbose "Could not read configuration - skipping telemetry"
            return
        }

        $Config = $ConfigContent | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $Config) {
            Write-Verbose "Invalid JSON configuration - skipping telemetry"
            return
        }

        # Check if telemetry is enabled (default to false - opt-in only)
        $TelemetryEnabled = $false
        if ($Config.TelemetrySettings -and $Config.TelemetrySettings.ALLOW_TELEMETRY) {
            $TelemetryEnabled = $Config.TelemetrySettings.ALLOW_TELEMETRY
        }

        Write-Host "🔍 [DEBUG] Config.TelemetrySettings exists: $($null -ne $Config.TelemetrySettings)" -ForegroundColor Yellow
        if ($Config.TelemetrySettings) {
            Write-Host "🔍 [DEBUG] Config.TelemetrySettings.ALLOW_TELEMETRY value: $($Config.TelemetrySettings.ALLOW_TELEMETRY)" -ForegroundColor Yellow
        }

        if (-not $TelemetryEnabled) {
            Write-Verbose "Telemetry disabled in configuration - skipping event: $EventName"
            Write-Host "❌ [DEBUG] Telemetry disabled or not configured - skipping event: $EventName" -ForegroundColor Red
            return
        }

        Write-Verbose "Telemetry enabled - preparing event: $EventName"
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

        # Create privacy-protected identifier (always encrypted & CONSISTENT)
        # Unify hashing so local + CI environments never diverge (previously raw hash fallback caused different distinct_id)
        $TenantIdentifier = $null
        if (Get-Command -Name Get-TelemetryIdentifier -ErrorAction SilentlyContinue) {
            try {
                $TenantIdentifier = Get-TelemetryIdentifier -TenantId $Context.TenantId
            }
            catch {
                Write-Verbose "Get-TelemetryIdentifier threw - falling back to inline salted hashing"
            }
        }
        if (-not $TenantIdentifier) {
            Write-Host "🔧 [DEBUG] Using inline salted hashing for tenant identifier" -ForegroundColor Yellow
            $Salt = "EasyPIM-Privacy-Salt-2025-PostHog"
            $StringToHash = "$($Context.TenantId)-$Salt"
            try {
                $HashedBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToHash))
                $TenantIdentifier = [System.BitConverter]::ToString($HashedBytes).Replace("-", "").ToLower()
            }
            catch {
                Write-Verbose "Failed inline salted hashing: $($_.Exception.Message)"
                $TenantIdentifier = $null
            }
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
        # Telemetry must never fail the main operation
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
    }
    catch {
        Write-Verbose "PostHog API call failed: $($_.Exception.Message)"
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
