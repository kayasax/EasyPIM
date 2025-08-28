# PowerShell Gallery Publication Test
# Test ExternalModuleDependencies approach for resolving prerelease module dependencies

Write-Host "Testing EasyPIM.Orchestrator manifest configuration..." -ForegroundColor Green

# Test manifest loading
try {
    $manifest = Test-ModuleManifest -Path "d:\WIP\EASYPIM\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1"
    Write-Host "✅ Manifest loads successfully" -ForegroundColor Green
    
    # Check ExternalModuleDependencies
    $psData = $manifest.PrivateData.PSData
    if ($psData.ExternalModuleDependencies -contains 'EasyPIM') {
        Write-Host "✅ ExternalModuleDependencies includes EasyPIM" -ForegroundColor Green
    } else {
        Write-Host "❌ ExternalModuleDependencies missing EasyPIM" -ForegroundColor Red
    }
    
    # Check RequiredModules doesn't include EasyPIM
    $hasEasyPIMInRequired = $manifest.RequiredModules | Where-Object { 
        ($_ -is [string] -and $_ -eq 'EasyPIM') -or 
        ($_ -is [hashtable] -and $_.ModuleName -eq 'EasyPIM') 
    }
    
    if (-not $hasEasyPIMInRequired) {
        Write-Host "✅ RequiredModules correctly excludes EasyPIM" -ForegroundColor Green
    } else {
        Write-Host "❌ RequiredModules still includes EasyPIM" -ForegroundColor Red
    }
    
    Write-Host "`nManifest Summary:" -ForegroundColor Cyan
    Write-Host "  Module: $($manifest.Name)" 
    Write-Host "  Version: $($manifest.Version)"
    Write-Host "  Prerelease: $($psData.Prerelease)"
    Write-Host "  RequiredModules: $($manifest.RequiredModules -join ', ')"
    Write-Host "  ExternalModuleDependencies: $($psData.ExternalModuleDependencies -join ', ')"
    
} catch {
    Write-Host "❌ Manifest validation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nChecking EasyPIM availability on PowerShell Gallery..." -ForegroundColor Green
try {
    $easyPIM = Find-Module -Name EasyPIM -IncludeAllVersions | Sort-Object Version -Descending | Select-Object -First 5
    Write-Host "✅ EasyPIM versions found on PowerShell Gallery:" -ForegroundColor Green
    $easyPIM | ForEach-Object {
        Write-Host "  - $($_.Name) v$($_.Version) $(if($_.AdditionalMetadata.IsPrerelease -eq 'true'){'(prerelease)'})" 
    }
} catch {
    Write-Host "❌ Error checking PowerShell Gallery: $($_.Exception.Message)" -ForegroundColor Red
}
