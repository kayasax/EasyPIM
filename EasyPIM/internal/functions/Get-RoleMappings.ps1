# Cache for role mappings
$script:roleCache = @{}

<#
.SYNOPSIS
Build quick-look role name/ID mappings for a subscription.

.DESCRIPTION
Queries Azure RBAC role definitions for the specified subscription and returns a hashtable with three maps: NameToId, IdToName, and FullPathToName. Results are cached per-subscription for performance in repeated operations.

.PARAMETER SubscriptionId
The Azure Subscription GUID to query role definitions from.

.EXAMPLE
Get-RoleMappings -SubscriptionId $subId
Use the maps for fast lookups when translating between role names and IDs.

.NOTES
Uses Get-AzRoleDefinition; requires an active Az context.
#>
function Get-RoleMappings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param([string]$SubscriptionId)

    # Cache key for this subscription
    $cacheKey = "roles_$SubscriptionId"

    # Return cached result if available
    if ($script:roleCache.ContainsKey($cacheKey)) {
        return $script:roleCache[$cacheKey]
    }

    # Get roles and build mappings
    $roles = Get-AzRoleDefinition -Scope "/subscriptions/$SubscriptionId"
    $mapping = @{
        NameToId = @{}
        IdToName = @{}
        FullPathToName = @{}
    }

    foreach ($role in $roles) {
        $mapping.NameToId[$role.Name] = $role.Id
        $mapping.IdToName[$role.Id] = $role.Name
        $fullPath = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleDefinitions/$($role.Id)"
        $mapping.FullPathToName[$fullPath] = $role.Name
    }

    # Cache and return
    $script:roleCache[$cacheKey] = $mapping
    return $mapping
}
