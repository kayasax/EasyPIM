function Invoke-EasyPIMOrchestrator {
    [CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact='Medium')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Top-level ShouldProcess invoked; inner creation functions also use ShouldProcess")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="False positive previously; pattern implemented below")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,

        [Parameter(Mandatory = $false)]
        [ValidateSet("initial", "delta")]
        [string]$Mode = "delta",

        [Parameter(Mandatory = $false)]
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
        [string[]]$PolicyOperations = @("All")
    )
    # Non-gating ShouldProcess: still emits WhatIf message but always executes body for rich simulation output.
    $null = $PSCmdlet.ShouldProcess("EasyPIM Orchestration lifecycle", "Execute")
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
            ($config.PSObject.Properties['AzureRolePolicies'] -and $config.AzureRolePolicies) -or
            ($config.PSObject.Properties['EntraRolePolicies'] -and $config.EntraRolePolicies) -or
            ($config.PSObject.Properties['GroupPolicies'] -and $config.GroupPolicies) -or
            ($config.PSObject.Properties['PolicyTemplates'] -and $config.PolicyTemplates) -or
            ($config.PSObject.Properties['Policies'] -and $config.Policies) -or
            ($config.PSObject.Properties['EntraRoles'] -and $config.EntraRoles.PSObject.Properties['Policies'] -and $config.EntraRoles.Policies) -or
            ($config.PSObject.Properties['AzureRoles'] -and $config.AzureRoles.PSObject.Properties['Policies'] -and $config.AzureRoles.Policies) -or
            ($config.PSObject.Properties['GroupRoles'] -and $config.GroupRoles.PSObject.Properties['Policies'] -and $config.GroupRoles.Policies)
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
                    if ($processedConfig.PSObject.Properties[$key]) {
                        $processedConfig.PSObject.Properties[$key].Value = $filteredPolicyConfig[$key]
                    } else {
                        $processedConfig | Add-Member -MemberType NoteProperty -Name $key -Value $filteredPolicyConfig[$key]
                    }
                }
            } else {
                # Merge all policy config with processed config
                foreach ($key in $policyConfig.Keys) {
                    if ($key -match ".*Policies$") {
                        if ($processedConfig.PSObject.Properties[$key]) {
                            $processedConfig.PSObject.Properties[$key].Value = $policyConfig[$key]
                        } else {
                            $processedConfig | Add-Member -MemberType NoteProperty -Name $key -Value $policyConfig[$key]
                        }
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

        # 3. Process policies FIRST (skip if requested) - CRITICAL: Policies must be applied before assignments to ensure compliance
        $policyResults = $null
        if (-not $SkipPolicies -and $policyConfig -and (
            ($policyConfig.ContainsKey('AzureRolePolicies') -and $policyConfig.AzureRolePolicies) -or
            ($policyConfig.ContainsKey('EntraRolePolicies') -and $policyConfig.EntraRolePolicies) -or
            ($policyConfig.ContainsKey('GroupPolicies') -and $policyConfig.GroupPolicies)
        )) {
            $effectivePolicyMode = if ($WhatIfPreference) { "validate" } else { "delta" }
            # Convert hashtable to PSCustomObject for the policy function
            $policyConfigObject = [PSCustomObject]$policyConfig
            $policyResults = New-EasyPIMPolicies -Config $policyConfigObject -TenantId $TenantId -SubscriptionId $SubscriptionId -PolicyMode $effectivePolicyMode -WhatIf:$WhatIfPreference

            if ($WhatIfPreference) {
                Write-Host "✅ Policy validation completed - role policies are configured correctly for assignment compliance" -ForegroundColor Green
            } else {
                Write-Host "✅ Policy configuration completed - proceeding with assignments using updated role policies" -ForegroundColor Green
            }
        } elseif ($SkipPolicies) {
            Write-Warning "⚠️ Policy processing skipped - assignments may not comply with intended role policies"
        }

        # 4. Perform cleanup operations AFTER policy processing (skip if requested)
        $cleanupResults = if ($Operations -contains "All" -and -not $SkipCleanup) {
            Write-Host "🧹 Performing cleanup operations based on updated policies..." -ForegroundColor Cyan
            Invoke-EasyPIMCleanup -Config $processedConfig -Mode $Mode -TenantId $TenantId -SubscriptionId $SubscriptionId -WhatIf:$WhatIfPreference
        } else {
            if ($SkipCleanup) {
                Write-Host "⚠️ Skipping cleanup as requested by SkipCleanup parameter" -ForegroundColor Yellow
            } else {
                Write-Host "⚠️ Skipping cleanup as specific operations were selected" -ForegroundColor Yellow
            }
            $null
        }

        # 5. Process assignments AFTER policies are confirmed (skip if requested)
        if (-not $SkipAssignments) {
            Write-Host "👥 Creating assignments with role policies validated and applied..." -ForegroundColor Cyan
            # New-EasyPIMAssignments does not itself expose -WhatIf; inner Invoke-ResourceAssignment handles simulation.
            $assignmentResults = New-EasyPIMAssignments -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId
        } else {
            Write-Host "⚠️ Skipping assignment creation as requested" -ForegroundColor Yellow
            $assignmentResults = $null
        }

        # 6. Display summary
        $effectivePolicyMode = if ($WhatIfPreference) { "validate" } else { "delta" }
        Write-EasyPIMSummary -CleanupResults $cleanupResults -AssignmentResults $assignmentResults -PolicyResults $policyResults -PolicyMode $effectivePolicyMode

        Write-Host "=== EasyPIM orchestration completed successfully ===" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ An error occurred: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}