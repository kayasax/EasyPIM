           function New-EasyPIMAssignments {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId
    )

    Write-Host "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" -ForegroundColor Cyan
    Write-Host "┃ Processing Assignments                                                       ┃" -ForegroundColor Cyan
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" -ForegroundColor Cyan

    $allResults = @()

    # Process Entra roles after Azure roles
    if ($Config.EntraRoles) {
        # Process eligible assignments
        Write-Host "`n▶ Processing Entra ID Role Eligible Assignments" -ForegroundColor White
        Write-Host "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄" -ForegroundColor DarkGray

        $cmdMap = @{
            GetCmd = "Get-PIMEntraRoleEligibleAssignment"
            GetParams = @{ tenantId = $TenantId }
            CreateCmd = "New-PIMEntraRoleEligibleAssignment"
            CreateParams = @{ tenantId = $TenantId }
            TenantId = $TenantId
        }

        $result = Process-PIMAssignments -Operation Create -ResourceType "Entra ID Role eligible" `
            -Assignments $Config.EntraRoles.EligibleAssignments `
            -ConfigAssignments $Config.EntraRoles.EligibleAssignments `
            -CommandMap $cmdMap -ProtectedUsers $Config.ProtectedUsers

        Write-Host "`n┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│ SUMMARY: Entra ID Role Eligible Assignments" -ForegroundColor Cyan
        Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
        Write-Host "│ ✅ Created : $($result.Created)" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $($result.Skipped)" -ForegroundColor White
        Write-Host "│ ❌ Failed  : $($result.Failed)" -ForegroundColor White
        Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan

        $allResults += @($result)

        # Process active assignments
        Write-Host "`n▶ Processing Entra ID Role Active Assignments" -ForegroundColor White
        Write-Host "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄" -ForegroundColor DarkGray

        $cmdMap = @{
            GetCmd = "Get-PIMEntraRoleActiveAssignment"
            GetParams = @{ tenantId = $TenantId }
            CreateCmd = "New-PIMEntraRoleActiveAssignment"
            CreateParams = @{ tenantId = $TenantId }
            TenantId = $TenantId
        }

        $result = Process-PIMAssignments -Operation Create -ResourceType "Entra ID Role active" `
            -Assignments $Config.EntraRoles.ActiveAssignments `
            -ConfigAssignments $Config.EntraRoles.ActiveAssignments `
            -CommandMap $cmdMap -ProtectedUsers $Config.ProtectedUsers

        Write-Host "`n┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│ SUMMARY: Entra ID Role Active Assignments" -ForegroundColor Cyan
        Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
        Write-Host "│ ✅ Created : $($result.Created)" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $($result.Skipped)" -ForegroundColor White
        Write-Host "│ ❌ Failed  : $($result.Failed)" -ForegroundColor White
        Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan

        $allResults += @($result)
    }

    return $allResults
}