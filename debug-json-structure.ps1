# Debug the exact JSON being sent to Microsoft Graph
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1 -Force -Global

# Enable full Graph error capture
$env:EASYPIM_DEBUG = '1'

try {
    Write-Host "=== Testing JSON structure for Graph API ===" -ForegroundColor Cyan

    # Test with DebugGraphPayload to see exact JSON
    $result = New-PIMEntraRoleActiveAssignment -TenantID $env:TENANTID -RoleName 'User Administrator' -PrincipalID '8b0995d0-4c07-4814-98c8-550dc0af62cf' -Duration 'PT1H' -Justification 'Debug JSON test' -DebugGraphPayload -ErrorAction Stop

    Write-Host "✅ SUCCESS: Assignment created" -ForegroundColor Green

} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red

    # Check if the error contains the actual Graph response
    $errorString = $_.Exception.Message
    if ($errorString -match 'reqBody= (.+)$') {
        $jsonBody = $matches[1]
        Write-Host "`n📝 Request Body Analysis:" -ForegroundColor Yellow
        Write-Host $jsonBody -ForegroundColor White

        # Try to parse the JSON to check for syntax errors
        try {
            $parsedJson = $jsonBody | ConvertFrom-Json
            Write-Host "`n✅ JSON is valid syntactically" -ForegroundColor Green
            Write-Host "📊 JSON Properties:" -ForegroundColor Cyan
            $parsedJson.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
            }
        } catch {
            Write-Host "`n❌ JSON PARSING ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "This indicates a syntax error in our JSON structure" -ForegroundColor Yellow
        }
    }
}

# Clean up
$env:EASYPIM_DEBUG = $null
