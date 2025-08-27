<#
.SYNOPSIS
    Converts ISO 8601 duration strings to TimeSpan objects.

.DESCRIPTION
    Parses ISO 8601 duration strings like P30D, PT8H, PT2H30M etc. into .NET TimeSpan objects.
    This is a helper function used by various PIM assignment functions for duration validation.

.PARAMETER iso
    The ISO 8601 duration string to parse (e.g., "P30D", "PT8H", "PT2H30M")

.RETURNS
    TimeSpan object representing the duration, or $null if parsing fails

.EXAMPLE
    PS> ConvertFrom-ISO8601Duration "P30D"
    Returns a TimeSpan representing 30 days

.EXAMPLE
    PS> ConvertFrom-ISO8601Duration "PT8H"
    Returns a TimeSpan representing 8 hours

.NOTES
    This is an internal helper function used across multiple PIM assignment functions.
#>
function ConvertFrom-ISO8601Duration {
    [CmdletBinding()]
    [OutputType([TimeSpan])]
    param(
        [string]$iso
    )

    if (-not $iso) { return $null }
    try {
        return [System.Xml.XmlConvert]::ToTimeSpan($iso)
    } catch {
        Write-Verbose "Suppressed ISO8601 duration parse failure: $($_.Exception.Message)"
    }
    return $null
}
