<#
.SYNOPSIS
    Formats TimeSpan objects into human-readable duration strings.

.DESCRIPTION
    Converts .NET TimeSpan objects into concise, human-readable format like "30d", "8h", "2h 30m", etc.
    This is a helper function used by various PIM assignment functions for user-friendly duration display.

.PARAMETER ts
    The TimeSpan object to format

.RETURNS
    String representing the duration in human-readable format

.EXAMPLE
    PS> Format-TimeSpanHuman (New-TimeSpan -Days 30)
    Returns "30d"

.EXAMPLE
    PS> Format-TimeSpanHuman (New-TimeSpan -Hours 8)
    Returns "8h"

.EXAMPLE
    PS> Format-TimeSpanHuman (New-TimeSpan -Hours 2 -Minutes 30)
    Returns "2h 30m"

.NOTES
    This is an internal helper function used across multiple PIM assignment functions.
#>
function Format-TimeSpanHuman {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [TimeSpan]$ts
    )

    if (-not $ts) { return '' }
    if ($ts.Days -ge 1 -and $ts.Hours -eq 0 -and $ts.Minutes -eq 0) { return "$($ts.Days)d" }
    if ($ts.Days -ge 1) { return "$($ts.Days)d $($ts.Hours)h" }
    if ($ts.TotalHours -ge 1 -and $ts.Minutes -eq 0) { return "$([int]$ts.TotalHours)h" }
    if ($ts.TotalHours -ge 1) { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
    if ($ts.Minutes -ge 1) { return "$($ts.Minutes)m" }
    return "$([math]::Round($ts.TotalSeconds))s"
}
