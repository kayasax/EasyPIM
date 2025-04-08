function Show-EasyPIMUsage {
    [CmdletBinding()]
    param()
    
    Write-Host @"
Usage: Invoke-EasyPIMOrchestrator [Parameters]

Required Parameters:
    -TenantId <string>
    -SubscriptionId <string>
    
One of these is required:
    -ConfigFilePath <string>
    -KeyVaultName <string> -SecretName <string>

Optional Parameters:
    -Mode <string>           Options: "initial" or "delta" (default: "delta")
    -Operations <string[]>   Options: "All", "AzureRoles", "EntraRoles", "GroupRoles" (default: "All")
                            You can specify multiple operations, e.g.: -Operations AzureRoles,EntraRoles
    -SkipAssignments        Switch to run only cleanup without creating new assignments

Examples:
    # Run all operations using a config file
    Invoke-EasyPIMOrchestrator -TenantId "tenant-id" -SubscriptionId "sub-id" -ConfigFilePath "config.json"

    # Run only cleanup operations (no new assignments)
    Invoke-EasyPIMOrchestrator -TenantId "tenant-id" -SubscriptionId "sub-id" -ConfigFilePath "config.json" -SkipAssignments

    # Run only Azure Role cleanup without new assignments
    Invoke-EasyPIMOrchestrator -TenantId "tenant-id" -SubscriptionId "sub-id" -ConfigFilePath "config.json" -Operations AzureRoles -SkipAssignments
"@ -ForegroundColor Cyan
}