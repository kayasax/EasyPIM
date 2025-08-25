# Load internal shared helpers
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal') -Filter *.ps1 -Recurse) {
    . $file.FullName
}
