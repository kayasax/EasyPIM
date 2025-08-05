function Invoke-EasyPIMOrchestrator {
    [CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,

        [Parameter(Mandatory = $false)]
        [ValidateSet("initial", "delta")]
        [string]$Mode = "delta",

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
        [string[]]$Operations = @("All"),

        [Parameter(Mandatory = $false)]
        [switch]$SkipAssignments,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCleanup,

        [Parameter(Mandatory = $false)]
        [switch]$SkipPolicies,

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
        [string[]]$PolicyOperations = @("All"),

        [Parameter(Mandatory = $false)]
        [ValidateSet("validate", "delta", "initial")]
        [string]$PolicyMode = "validate"
    )

    Write-SectionHeader "Starting EasyPIM Orchestration (Mode: $Mode)"

    # Display usage if no parameters are provided
    if (-not $PSBoundParameters) {
        Show-EasyPIMUsage
        return
    }

    try {
        # Import necessary modules
        #Write-Host "Importing required modules..." -ForegroundColor Gray
        #Import-Module Az.KeyVault, Az.Resources

        # 1. Load configuration
        $config = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
        } else {
            Get-EasyPIMConfiguration -ConfigFilePath $ConfigFilePath
        }

        # 2. Process and normalize config based on selected operations
        $processedConfig = Initialize-EasyPIMAssignments -Config $config

        # 2.1. Process policy configurations if present
        $policyConfig = $null
        if (-not $SkipPolicies -and (
            $config.ContainsKey('AzureRolePolicies') -or 
            $config.ContainsKey('EntraRolePolicies') -or 
            $config.ContainsKey('GroupPolicies') -or 
            $config.ContainsKey('PolicyTemplates')
        )) {
            Write-Host "🔧 Processing policy configurations..." -ForegroundColor Cyan
            $policyConfig = Initialize-EasyPIMPolicies -Config $config
            
            # Filter policy config based on selected policy operations
            if ($PolicyOperations -notcontains "All") {
                $filteredPolicyConfig = @{}
                foreach ($op in $PolicyOperations) {
                    switch ($op) {
                        "AzureRoles" {
                            if ($policyConfig.ContainsKey('AzureRolePolicies')) {
                                $filteredPolicyConfig.AzureRolePolicies = $policyConfig.AzureRolePolicies
                            }
                        }
                        "EntraRoles" {
                            if ($policyConfig.ContainsKey('EntraRolePolicies')) {
                                $filteredPolicyConfig.EntraRolePolicies = $policyConfig.EntraRolePolicies
                            }
                        }
                        "GroupRoles" {
                            if ($policyConfig.ContainsKey('GroupPolicies')) {
                                $filteredPolicyConfig.GroupPolicies = $policyConfig.GroupPolicies
                            }
                        }
                    }
                }
                # Merge filtered policy config with processed config
                foreach ($key in $filteredPolicyConfig.Keys) {
                    $processedConfig[$key] = $filteredPolicyConfig[$key]
                }
            } else {
                # Merge all policy config with processed config
                foreach ($key in $policyConfig.Keys) {
                    if ($key -match ".*Policies$") {
                        $processedConfig[$key] = $policyConfig[$key]
                    }
                }
            }
        } elseif ($SkipPolicies) {
            Write-Host "⚠️ Skipping policy processing as requested by SkipPolicies parameter" -ForegroundColor Yellow
        }

        # Filter config based on selected operations
        if ($Operations -notcontains "All") {
            $filteredConfig = @{}
            foreach ($op in $Operations) {
                switch ($op) {
                    "AzureRoles" {
                        $filteredConfig.AzureRoles = $processedConfig.AzureRoles
                        $filteredConfig.AzureRolesActive = $processedConfig.AzureRolesActive
                    }
                    "EntraRoles" {
                        $filteredConfig.EntraIDRoles = $processedConfig.EntraIDRoles
                        $filteredConfig.EntraIDRolesActive = $processedConfig.EntraIDRolesActive
                    }
                    "GroupRoles" {
                        $filteredConfig.GroupRoles = $processedConfig.GroupRoles
                        $filteredConfig.GroupRolesActive = $processedConfig.GroupRolesActive
                    }
                }
            }
            $processedConfig = $filteredConfig
        }

        # 3. Perform cleanup operations if running full operations or specific role types (skip if requested)
        $cleanupResults = if ($Operations -contains "All" -and -not $SkipCleanup) {
            Invoke-EasyPIMCleanup -Config $processedConfig -Mode $Mode -TenantId $TenantId -SubscriptionId $SubscriptionId
        } else {
            if ($SkipCleanup) {
                Write-Host "⚠️ Skipping cleanup as requested by SkipCleanup parameter" -ForegroundColor Yellow
            } else {
                Write-Host "⚠️ Skipping cleanup as specific operations were selected" -ForegroundColor Yellow
            }
            $null
        }

        # 4. Process policies (skip if requested)
        $policyResults = $null
        if (-not $SkipPolicies -and $policyConfig -and (
            $processedConfig.ContainsKey('AzureRolePolicies') -or 
            $processedConfig.ContainsKey('EntraRolePolicies') -or 
            $processedConfig.ContainsKey('GroupPolicies')
        )) {
            $policyResults = New-EasyPIMPolicies -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId -PolicyMode $PolicyMode
        }

        # 5. Process assignments (skip if requested)
        if (-not $SkipAssignments) {
            $assignmentResults = New-EasyPIMAssignments -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId
        } else {
            Write-Host "⚠️ Skipping assignment creation as requested" -ForegroundColor Yellow
            $assignmentResults = $null
        }

        # 6. Display summary
        Write-EasyPIMSummary -CleanupResults $cleanupResults -AssignmentResults $assignmentResults -PolicyResults $policyResults

        Write-Host "=== EasyPIM orchestration completed successfully ===" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ An error occurred: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}