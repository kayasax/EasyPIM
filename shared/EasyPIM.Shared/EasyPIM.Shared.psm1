# Load internal shared helpers
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal') -Filter *.ps1 -Recurse) {
    . $file.FullName
}

# Export only the minimal helpers needed by parent modules
Export-ModuleMember -Function @('Write-SectionHeader','Initialize-EasyPIMAssignments')
