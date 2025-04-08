function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $Message" -ForegroundColor Cyan
    Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
}

function Write-SubHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-StatusInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "  ℹ️ $Message" -ForegroundColor White
}

function Write-StatusSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-StatusWarning {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "  ⚠️ $Message" -ForegroundColor Yellow
}

function Write-StatusError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-CleanupSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [int]$Kept,
        
        [Parameter(Mandatory = $true)]
        [int]$Removed,
        
        [Parameter(Mandatory = $true)]
        [int]$Protected
    )
    
    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $Category Summary" -ForegroundColor Cyan
    Write-Host "├────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ ✅ Kept:      $Kept" -ForegroundColor White
    Write-Host "│ 🗑️ Removed:   $Removed" -ForegroundColor White
    Write-Host "│ 🛡️ Protected: $Protected" -ForegroundColor White
    Write-Host "└────────────────────────────────────────────────────┘" -ForegroundColor Cyan
}