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
        [switch]$SkipCleanup
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

        # 4. Process assignments (skip if requested)
        if (-not $SkipAssignments) {
            $assignmentResults = New-EasyPIMAssignments -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId
        } else {
            Write-Host "⚠️ Skipping assignment creation as requested" -ForegroundColor Yellow
            $assignmentResults = $null
        }

        # 5. Display summary
        Write-EasyPIMSummary -CleanupResults $cleanupResults -AssignmentResults $assignmentResults

        Write-Host "=== EasyPIM orchestration completed successfully ===" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ An error occurred: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}