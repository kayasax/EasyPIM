function Invoke-EasyPIMCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("initial", "delta")]
        [string]$Mode = "delta"
    )

    # Confirm the operation with the user
    $operationTarget = "PIM assignments across Azure, Entra ID, and Groups"
    $operationDescription = "$Mode mode cleanup - process assignments according to configuration"
    if (-not $PSCmdlet.ShouldProcess($operationTarget, $operationDescription)) {
        Write-Output "Operation cancelled by user."
        return @{
            KeptCount = 0
            RemovedCount = 0
            SkippedCount = 0
            ProtectedCount = 0
        }
    }

    $results = @()

    # Process Azure Resource roles (eligible)
    if ($Config.AzureRoles) {
        $apiInfo = @{
            TenantId = $TenantId
            SubscriptionId = $SubscriptionId
        }
        $results += Invoke-Cleanup -ResourceType "Azure Role eligible" -ConfigAssignments $Config.AzureRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
    }

    # Process Azure Resource roles (active)
    if ($Config.AzureRolesActive) {
        $apiInfo = @{
            TenantId = $TenantId
            SubscriptionId = $SubscriptionId
        }
        $results += Invoke-Cleanup -ResourceType "Azure Role active" -ConfigAssignments $Config.AzureRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
    }

    # Process Entra ID roles (eligible)
    if ($Config.EntraIDRoles) {
        $apiInfo = @{
            TenantId = $TenantId
        }
        $results += Invoke-Cleanup -ResourceType "Entra Role eligible" -ConfigAssignments $Config.EntraIDRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
    }

    # Process Entra ID roles (active)
    if ($Config.EntraIDRolesActive) {
        $apiInfo = @{
            TenantId = $TenantId
        }
        $results += Invoke-Cleanup -ResourceType "Entra Role active" -ConfigAssignments $Config.EntraIDRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
    }

    # Process Group roles (eligible)
    if ($Config.GroupRoles) {
        foreach ($groupConfig in $Config.GroupRoles) {
            if ($groupConfig.GroupId) {
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupConfig.GroupId)
                }
                $results += Invoke-Cleanup -ResourceType "Group eligible" -ConfigAssignments $Config.GroupRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
            }
        }
    }

    # Process Group roles (active)
    if ($Config.GroupRolesActive) {
        foreach ($groupConfig in $Config.GroupRolesActive) {
            if ($groupConfig.GroupId) {
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupConfig.GroupId)
                }
                $results += Invoke-Cleanup -ResourceType "Group active" -ConfigAssignments $Config.GroupRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode
            }
        }
    }

    # Aggregate results
    $totalKept = ($results | Measure-Object -Property KeptCount -Sum).Sum
    $totalRemoved = ($results | Measure-Object -Property RemovedCount -Sum).Sum
    $totalSkipped = ($results | Measure-Object -Property SkippedCount -Sum).Sum
    $totalProtected = ($results | Measure-Object -Property ProtectedCount -Sum).Sum

    return @{
        KeptCount = $totalKept
        RemovedCount = $totalRemoved
        SkippedCount = $totalSkipped
        ProtectedCount = $totalProtected
    }
}