# Monitor Core Workflow and Trigger Orchestrator
# This script monitors the core workflow and triggers orchestrator when ready

Write-Host "🔍 Monitoring EasyPIM Core v2.0.0 Publication..." -ForegroundColor Cyan

$maxAttempts = 20
$attempt = 0
$found = $false

while ($attempt -lt $maxAttempts -and -not $found) {
    $attempt++
    Write-Host "📅 Attempt $attempt/$maxAttempts - Checking PowerShell Gallery..." -ForegroundColor Yellow
    
    try {
        # Check if EasyPIM v2.0.0 is available
        $module = Find-Module -Name EasyPIM -Repository PSGallery -ErrorAction SilentlyContinue
        
        if ($module -and $module.Version -eq '2.0.0') {
            Write-Host "✅ SUCCESS: EasyPIM v2.0.0 found on PowerShell Gallery!" -ForegroundColor Green
            Write-Host "   Version: $($module.Version)" -ForegroundColor Green
            Write-Host "   Published: $($module.PublishedDate)" -ForegroundColor Green
            $found = $true
            
            # Trigger orchestrator workflow
            Write-Host "🚀 Triggering Orchestrator Workflow..." -ForegroundColor Cyan
            try {
                Start-Process -FilePath "gh" -ArgumentList "workflow","run","build-orchestrator.yml" -WorkingDirectory "d:\WIP\EASYPIM" -Wait
                Write-Host "✅ Orchestrator workflow triggered successfully!" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to trigger orchestrator workflow: $($_.Exception.Message)" -ForegroundColor Red
            }
            
        } else {
            Write-Host "⏳ EasyPIM v2.0.0 not yet available. Current version: $($module.Version -or 'Not found')" -ForegroundColor Yellow
            Start-Sleep 30
        }
    } catch {
        Write-Host "⚠️ Error checking PowerShell Gallery: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep 30
    }
}

if (-not $found) {
    Write-Host "❌ Timeout: EasyPIM v2.0.0 not found after $maxAttempts attempts" -ForegroundColor Red
    Write-Host "💡 You may need to manually check the core workflow and trigger orchestrator" -ForegroundColor Yellow
}

Write-Host "📋 Monitoring complete." -ForegroundColor Cyan
