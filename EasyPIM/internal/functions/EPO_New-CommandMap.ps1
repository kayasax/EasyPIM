function New-CommandMap {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AzureRoleEligible', 'AzureRoleActive', 'EntraRoleEligible',
                     'EntraRoleActive', 'GroupRoleEligible', 'GroupRoleActive')]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter()]
        [string]$SubscriptionId,
        
        [Parameter()]
        [object]$FirstAssignment,
        
        [Parameter()]
        [string]$GroupId
    )
    
    # Generate justification once
    $justification = Get-EasyPIMJustification -IncludeTimestamp
    Write-Verbose "Using justification: $justification"
    
    # Create the appropriate command map based on resource type
    switch ($ResourceType) {
        "AzureRoleEligible" {
            $commandMap = @{
                GetCmd       = 'Get-PIMAzureResourceEligibleAssignment'
                GetParams    = @{
                    tenantID       = $TenantId
                    subscriptionID = $SubscriptionId
                }
                CreateCmd    = 'New-PIMAzureResourceEligibleAssignment'
                CreateParams = @{
                    tenantID       = $TenantId
                    subscriptionID = $SubscriptionId
                    justification  = $justification # Explicitly set justification
                }
                DirectFilter = $true
            }
        }
        "AzureRoleActive" {
            $commandMap = @{
                GetCmd       = 'Get-PIMAzureResourceActiveAssignment'
                GetParams    = @{
                    tenantID       = $TenantId
                    subscriptionID = $SubscriptionId
                }
                CreateCmd    = 'New-PIMAzureResourceActiveAssignment'
                CreateParams = @{
                    tenantID       = $TenantId
                    subscriptionID = $SubscriptionId
                    justification  = $justification # Explicitly set justification
                }
                DirectFilter = $true
            }
        }
        "EntraRoleEligible" {
            $commandMap = @{
                GetCmd       = 'Get-PIMEntraRoleEligibleAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                }
                CreateCmd    = 'New-PIMEntraRoleEligibleAssignment'
                CreateParams = @{
                    tenantID      = $TenantId
                    justification = $justification # Explicitly set justification
                }
                DirectFilter = $true
            }
        }
        "EntraRoleActive" {
            $commandMap = @{
                GetCmd       = 'Get-PIMEntraRoleActiveAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                }
                CreateCmd    = 'New-PIMEntraRoleActiveAssignment'
                CreateParams = @{
                    tenantID      = $TenantId
                    justification = $justification # Explicitly set justification
                }
                DirectFilter = $true
            }
        }
        "GroupRoleEligible" {
            # Determine groupID - FirstAssignment.GroupId takes priority over parameter
            $effectiveGroupId = if ($FirstAssignment -and $FirstAssignment.GroupId) {
                $FirstAssignment.GroupId
            }
            elseif (-not [string]::IsNullOrEmpty($GroupId)) {
                $GroupId
            }
            else {
                Write-Warning "No GroupId available for GroupRoleEligible command map"
                $null
            }
            
            # IMPORTANT: Only include groupID in GetParams - it's required for listing
            $commandMap = @{
                GetCmd       = 'Get-PIMGroupEligibleAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                    # Include groupID in GetParams ONLY - it's required
                    groupID  = $effectiveGroupId
                }
                CreateCmd    = 'New-PIMGroupEligibleAssignment'
                CreateParams = @{
                    tenantID      = $TenantId
                    # DO NOT include other parameters like principalID, etc.
                    # These will be added for each specific assignment
                    justification = $justification
                }
                DirectFilter = $true
            }
        }
        "GroupRoleActive" {
            # Determine groupID - FirstAssignment.GroupId takes priority over parameter
            $effectiveGroupId = if ($FirstAssignment -and $FirstAssignment.GroupId) {
                $FirstAssignment.GroupId
            }
            elseif (-not [string]::IsNullOrEmpty($GroupId)) {
                $GroupId
            }
            else {
                Write-Warning "No GroupId available for GroupRoleActive command map"
                $null
            }
            
            # IMPORTANT: Only include groupID in GetParams - it's required for listing
            $commandMap = @{
                GetCmd       = 'Get-PIMGroupActiveAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                    # Include groupID in GetParams ONLY - it's required
                    groupID  = $effectiveGroupId
                }
                CreateCmd    = 'New-PIMGroupActiveAssignment'
                CreateParams = @{
                    tenantID      = $TenantId
                    # DO NOT include other parameters like principalID, etc.
                    # These will be added for each specific assignment
                    justification = $justification
                }
                DirectFilter = $true
            }
        }
    }
    
    return $commandMap
}