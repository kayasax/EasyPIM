<#
.SYNOPSIS
    Disables telemetry collection for EasyPIM.Orchestrator

.DESCRIPTION
    Updates the configuration file to disable telemetry collection.
    This is a convenience function for users who want to opt-out of
    anonymous usage statistics.

.PARAMETER ConfigurationFile
    Path to the EasyPIM configuration file to update

.EXAMPLE
    Disable-EasyPIMTelemetry -ConfigurationFile ".\pim-config.json"
    Disables telemetry in the specified configuration file

.NOTES
    Author: Loïc MICHEL
    This function provides an easy way to opt-out of telemetry collection
#>
function Disable-EasyPIMTelemetry {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigurationFile
    )

    try {
        if (-not (Test-Path $ConfigurationFile)) {
            Write-Error "Configuration file not found: $ConfigurationFile"
            return
        }

        $Config = Get-Content $ConfigurationFile -Raw | ConvertFrom-Json

        # Ensure TelemetrySettings exists
        if (-not $Config.TelemetrySettings) {
            $Config | Add-Member -NotePropertyName "TelemetrySettings" -NotePropertyValue @{} -Force
        }

        # Disable telemetry
        $Config.TelemetrySettings.ALLOW_TELEMETRY = $false

        if ($PSCmdlet.ShouldProcess($ConfigurationFile, "Disable telemetry")) {
            $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigurationFile -Encoding UTF8
            Write-Host "✅ Telemetry disabled in $ConfigurationFile" -ForegroundColor Green
            Write-Host "   No usage data will be collected." -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Failed to disable telemetry: $($_.Exception.Message)"
    }
}
