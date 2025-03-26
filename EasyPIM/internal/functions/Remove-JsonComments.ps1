function Remove-JsonComments {
    [CmdletBinding()]
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