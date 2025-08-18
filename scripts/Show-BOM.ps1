param([Parameter(Mandatory=$true)][string]$Path)
if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$bytes = [System.IO.File]::ReadAllBytes($Path)
if ($bytes.Length -lt 3) { Write-Output "<no-bom>"; exit }
'{0:X2} {1:X2} {2:X2}' -f $bytes[0],$bytes[1],$bytes[2]
