function Write-SectionHeader {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $Message" -ForegroundColor Cyan
    Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
}
