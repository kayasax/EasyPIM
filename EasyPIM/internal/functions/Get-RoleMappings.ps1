# Cache for role mappings
$script:roleCache = @{}

function Get-RoleMappings {
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
