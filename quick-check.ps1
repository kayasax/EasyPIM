# Simple check and trigger script
Write-Host "Checking EasyPIM v2.0.0 availability..." -ForegroundColor Cyan

try {
    $module = Find-Module -Name EasyPIM -Repository PSGallery
    Write-Host "Current EasyPIM version on PSGallery: $($module.Version)" -ForegroundColor Yellow
    
    if ($module.Version -eq '2.0.0') {
        Write-Host "SUCCESS: v2.0.0 is available! Triggering orchestrator..." -ForegroundColor Green
        & gh workflow run build-orchestrator.yml
        Write-Host "Orchestrator workflow triggered!" -ForegroundColor Green
    } else {
        Write-Host "v2.0.0 not yet available. Please wait and try again." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
