<#
.SYNOPSIS
    Validates telemetry configuration and prompts for consent if needed

.DESCRIPTION
    Checks if telemetry settings exist in configuration and prompts user
    for consent on first run. Updates configuration file with user choice.

.PARAMETER ConfigPath
    Path to the configuration file

.PARAMETER Silent
    If specified, skips interactive prompts (for automation scenarios)

.OUTPUTS
    Boolean indicating if telemetry is enabled

.EXAMPLE
    Test-TelemetryConfiguration -ConfigPath "config.json"
    Checks telemetry settings and prompts if needed

.NOTES
    Author: Loïc MICHEL
    Privacy: Defaults to disabled, requires explicit user consent
#>
function Test-TelemetryConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter()]
        [switch]$Silent
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Verbose "Configuration file not found: $ConfigPath"
            return $false
        }
        
        $ConfigContent = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
        if (-not $ConfigContent) {
            Write-Verbose "Could not read configuration file"
            return $false
        }
        
        $Config = $ConfigContent | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $Config) {
            Write-Verbose "Invalid JSON in configuration file"
            return $false
        }
        
        # Check if telemetry settings exist
        if (-not $Config.TelemetrySettings) {
            if ($Silent) {
                Write-Verbose "No telemetry settings found, silent mode - defaulting to disabled"
                return $false
            }
            
            # First run - prompt for telemetry consent
            Write-Host ""
            Write-Host "📊 Help Improve EasyPIM" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "EasyPIM can collect anonymous usage statistics to help improve the tool:" -ForegroundColor White
            Write-Host "  • Execution metrics (success rates, performance)" -ForegroundColor Gray
            Write-Host "  • Feature usage patterns (which operations are used)" -ForegroundColor Gray
            Write-Host "  • Error rates and categories (to identify issues)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Privacy Protection:" -ForegroundColor Green
            Write-Host "  ✓ Tenant ID is encrypted (SHA256) - never sent in clear text" -ForegroundColor Green
            Write-Host "  ✓ No personal information (names, emails, roles) is collected" -ForegroundColor Green
            Write-Host "  ✓ No sensitive PIM data or configuration details are transmitted" -ForegroundColor Green
            Write-Host ""
            Write-Host "Learn more: " -NoNewline -ForegroundColor White
            Write-Host "https://github.com/kayasax/EasyPIM/blob/main/TELEMETRY.md" -ForegroundColor Blue
            Write-Host ""
            
            $TelemetryChoice = Read-Host "Enable anonymous telemetry? (y/N)"
            
            # Add telemetry settings to configuration
            $TelemetryEnabled = ($TelemetryChoice -eq 'y' -or $TelemetryChoice -eq 'Y')
            
            $Config | Add-Member -NotePropertyName "TelemetrySettings" -NotePropertyValue @{
                ALLOW_TELEMETRY = $TelemetryEnabled
            } -Force
            
            # Save updated configuration
            try {
                $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
                
                if ($TelemetryEnabled) {
                    Write-Host ""
                    Write-Host "✅ Anonymous telemetry enabled. Thank you for helping improve EasyPIM!" -ForegroundColor Green
                    Write-Host "   You can disable it anytime by setting ALLOW_TELEMETRY to false in your config." -ForegroundColor Gray
                }
                else {
                    Write-Host ""
                    Write-Host "✅ Telemetry disabled. No usage data will be collected." -ForegroundColor Yellow
                }
                Write-Host ""
            }
            catch {
                Write-Warning "Could not save telemetry preference to configuration file: $($_.Exception.Message)"
            }
            
            return $TelemetryEnabled
        }
        
        # Return current telemetry setting
        return [bool]$Config.TelemetrySettings.ALLOW_TELEMETRY
    }
    catch {
        Write-Verbose "Error checking telemetry configuration: $($_.Exception.Message)"
        return $false
    }
}
