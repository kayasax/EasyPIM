param(
    [Parameter(Mandatory=$true)][string]$Path
)
if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$bytes = [System.IO.File]::ReadAllBytes($Path)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Verbose "Already has BOM"; return
}
$utf8bom = [byte[]]@(0xEF,0xBB,0xBF)
[System.IO.File]::WriteAllBytes($Path, $utf8bom + $bytes)
