# Test script to verify Initialize-EasyPIMAssignments function is working
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force

# Create sample assignment configuration
$sampleConfig = @{
    Assignments = @{
        EntraRoles = @(
            @{
                roleName = 'Security Reader'
                principal = 'test@example.com'
                assignmentType = 'Eligible'
                duration = 'P30D'
            },
            @{
                roleName = 'Global Reader'
                principal = 'test2@example.com'
                assignmentType = 'Active'
                duration = 'P15D'
            }
        )
    }
}

Write-Host "Testing Initialize-EasyPIMAssignments function..."

try {
    # This should now work without PowerShell array errors
    $result = Initialize-EasyPIMAssignments -AssignmentConfiguration $sampleConfig -Verbose
    
    Write-Host "SUCCESS: Function executed without errors" -ForegroundColor Green
    Write-Host "Assignment counts:"
    Write-Host "  EntraIDRoles (Eligible): $($result.EntraIDRoles.Count)" -ForegroundColor Cyan
    Write-Host "  EntraIDRolesActive (Active): $($result.EntraIDRolesActive.Count)" -ForegroundColor Cyan
    Write-Host "  AzureRoles: $($result.AzureRoles.Count)" -ForegroundColor Cyan
    Write-Host "  AzureRolesActive: $($result.AzureRolesActive.Count)" -ForegroundColor Cyan
    Write-Host "  GroupRoles: $($result.GroupRoles.Count)" -ForegroundColor Cyan
    Write-Host "  GroupRolesActive: $($result.GroupRolesActive.Count)" -ForegroundColor Cyan
    
    Write-Host "`nExpected result: Entra(E:1 A:1) instead of Entra(E:0 A:0)" -ForegroundColor Yellow
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
