# Quick test of just the basic structure - let me create a minimal version to identify the syntax issue
function Test-MinimalFunction {
    try {
        Write-Host "In try block"
        return "success"
    }
    catch {
        Write-Error "Error: $($_.Exception.Message)"
        throw $_
    }
}

# Test it
Test-MinimalFunction
