function Write-SectionHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Title)
    Write-Host "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" -ForegroundColor Cyan
    Write-Host "┃ $($Title.PadRight(76)) ┃" -ForegroundColor Cyan
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" -ForegroundColor Cyan
}

function Write-SubHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Title)
    Write-Host "`n▶ $Title" -ForegroundColor Yellow
    Write-Host "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄" -ForegroundColor DarkGray
}

function Write-GroupHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Title)
    # Truncate title if it's too long
    if ($Title.Length -gt 65) {
        $Title = $Title.Substring(0, 62) + "..."
    }
    $remainingLength = [Math]::Max(0, (70 - $Title.Length))
    Write-Host "`n┌─── $Title $("─" * $remainingLength)" -ForegroundColor Magenta
}

function Write-StatusSuccess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-StatusInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Message)
    Write-Host "ℹ️ $Message" -ForegroundColor Blue
}

function Write-StatusProcessing {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param ([string]$Message)
    Write-Host "⚙️ $Message" -ForegroundColor Gray
}

function Write-StatusWarning {
    param ([string]$Message)
    Write-Warning "⚠️ $Message"
}

function Write-StatusError {
    param ([string]$Message)
    Write-Error "❌ $Message"
}

function Write-Summary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [string]$Category,
        [int]$Created = 0,
        [int]$Removed = 0,
        [int]$Skipped = 0,
        [int]$Failed = 0,
        [int]$Protected = 0,
        [ValidateSet("Creation", "Cleanup")]
        [string]$OperationType = "Creation"
    )

    Write-Host "`n┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ SUMMARY: $Category" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

    if ($OperationType -eq "Cleanup") {
        # Use the right labels for cleanup operations
        Write-Host "│ ✅ Kept    : $Created" -ForegroundColor White  # Reuse Created parameter for kept
        Write-Host "│ 🗑️ Removed : $Removed" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $Skipped" -ForegroundColor White
        if ($Protected -gt 0) {
            Write-Host "│ 🛡️ Protected: $Protected" -ForegroundColor White
        }
    } else {
        # Default creation display
        Write-Host "│ ✅ Created : $Created" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $Skipped" -ForegroundColor White
        Write-Host "│ ❌ Failed  : $Failed" -ForegroundColor White
    }

    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
}

function Write-CleanupSummary {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [int]$Kept,
        
        [Parameter(Mandatory = $true)]
        [int]$Removed,
        
        [Parameter(Mandatory = $true)]
        [int]$Protected
    )
    
    Write-Host "`n┌───────────────────────────────────────────────────────────────────────────────┐"
    Write-Host "│ SUMMARY: $Category"
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤"
    Write-Host "│ ✅ Kept    : $Kept"
    Write-Host "│ 🗑️ Removed : $Removed"
    Write-Host "│ ⏭️ Protected: $Protected"
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘"
    if ($Protected -gt 0) {
        Write-Host "ℹ️ Protected assignments skipped: $Protected"
    }
}

function Write-CreationSummary {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [int]$Created,
        
        [Parameter(Mandatory = $true)]
        [int]$Skipped,
        
        [Parameter(Mandatory = $true)]
        [int]$Failed
    )
    
    Write-Host "`n┌───────────────────────────────────────────────────────────────────────────────┐"
    Write-Host "│ SUMMARY: $Category"
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤"
    Write-Host "│ ✅ Created : $Created"
    Write-Host "│ ⏭️ Skipped : $Skipped"
    Write-Host "│ ❌ Failed  : $Failed"
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘"
}