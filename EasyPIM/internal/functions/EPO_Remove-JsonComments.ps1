function Remove-JsonComments {
    [CmdletBinding()]
    [OutputType([System.String])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$JsonContent
    )

    process {
        # Remove single-line comments (// ...)
        $JsonContent = [Regex]::Replace($JsonContent, '//.*?($|\r|\n)', '')

        # Remove multi-line comments (/* ... */)
        $JsonContent = [Regex]::Replace($JsonContent, '/\*[\s\S]*?\*/', '')

        return $JsonContent
    }
}
