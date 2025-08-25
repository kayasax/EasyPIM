function Write-SectionHeader {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    # ASCII-only to avoid CI encoding/parser issues
    Write-Host "" -ForegroundColor Cyan
    Write-Host "+----------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| $Message" -ForegroundColor Cyan
    Write-Host "+----------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
}
