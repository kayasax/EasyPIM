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
        [string]$TenantId
    )

    Write-SectionHeader "Starting EasyPIM Orchestration (Mode: $Mode)"

    # Display usage if no parameters are provided
    if (-not $PSBoundParameters) {
        Show-EasyPIMUsage
        return
    }

    try {
        # Import necessary modules
        Write-Host "Importing required modules..." -ForegroundColor Gray
        Import-Module Az.KeyVault, Az.Resources

        # 1. Load configuration
        $config = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
        } else {
            Get-EasyPIMConfiguration -ConfigFilePath $ConfigFilePath
        }
        # 2. Process and normalize config
        $processedConfig = Initialize-EasyPIMAssignments -Config $config
        
        # 3. Perform cleanup operations
        $cleanupResults = Invoke-EasyPIMCleanup -Config $processedConfig -Mode $Mode -TenantId $TenantId -SubscriptionId $SubscriptionId
        
        # 4. Process assignments
        $assignmentResults = New-EasyPIMAssignments -Config $processedConfig -TenantId $TenantId -SubscriptionId $SubscriptionId
        
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