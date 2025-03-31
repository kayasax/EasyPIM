<#
    .SYNOPSIS
        Orchestrates the deployment and management of PIM (Privileged Identity Management) assignments in Azure, Entra ID, and Groups.

    .DESCRIPTION
        The Invoke-EasyPIMOrchestrator function provides a comprehensive way to manage PIM assignments across your Azure environment.
        It supports both eligible and active assignments for Azure resources, Entra ID roles, and Groups.
        
        The function uses a JSON configuration file to define the desired state of PIM assignments and can operate in two modes:
        - delta mode: Only removes assignments that were created by this function and are no longer in the configuration
        - initial mode: Removes all assignments not in the configuration (except for protected users)
        
        The configuration can be stored in an Azure Key Vault secret or in a local JSON file.

    .PARAMETER KeyVaultName
        The name of the Azure Key Vault that contains the configuration secret.

    .PARAMETER SecretName
        The name of the secret in the Azure Key Vault that contains the configuration.

    .PARAMETER SubscriptionId
        The ID of the Azure subscription.

    .PARAMETER ConfigFilePath
        The path to the JSON configuration file.

    .PARAMETER Mode
        The operating mode for the function. Valid values are "initial" and "delta".
        
        In "initial" mode, all assignments not defined in the configuration will be removed, except for those assigned to protected users.
        In "delta" mode, only assignments created by this function that are no longer in the configuration will be removed.
        
        Default is "delta".

    .PARAMETER TenantId
        The ID of the Azure tenant.

    .EXAMPLE
        Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -Mode "delta"
        
        Deploys PIM assignments from a local configuration file using delta mode.

    .EXAMPLE
        Invoke-EasyPIMOrchestrator -KeyVaultName "MyKeyVault" -SecretName "PIMConfig" -SubscriptionId "22222222-2222-2222-2222-222222222222" -TenantId "11111111-1111-1111-1111-111111111111" -Mode "initial"
        
        Deploys PIM assignments from a Key Vault secret using initial mode.

    .EXAMPLE
        Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -WhatIf
        
        Shows what changes would be made without actually applying them.

    .NOTES
        Configuration File Structure:
        {
          "AzureRoles": [  // Eligible assignments
            {
              "PrincipalId": "00000000-0000-0000-0000-000000000001",
              "Role": "Reader",
              "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
              "Permanent": true  // Set to true for permanent eligible assignments
            }
          ],
          "AzureRolesActive": [  // Active assignments
            {
              "PrincipalId": "00000000-0000-0000-0000-000000000003",
              "Role": "Reader",
              "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
              "Duration": "PT8H",  // Time-bound active assignment
              "Permanent": true    // Can also be set to true for permanent active assignments
            }
          ],
          "EntraIDRoles": [...],
          "EntraIDRolesActive": [...],
          "GroupRoles": [...],
          "GroupRolesActive": [...],
          "ProtectedUsers": [
            "00000000-0000-0000-0000-000000000099"
          ]
        }
        
        For eligible assignments:
        - Set "Permanent": true for permanent assignments that don't expire
        - Set "Duration": "P90D" for time-bound assignments with specific duration
        - If neither is specified, maximum allowed duration by policy will be used
        - If both are specified, Permanent takes precedence
        
        For active assignments:
        - Set "Duration": "PT8H" for time-bound active assignments
        - Set "Permanent": true for permanent active assignments
        - If both are specified, Permanent takes precedence
        
        Duration format follows ISO 8601 (e.g., "PT8H" for 8 hours, "P1D" for 1 day)
        
        Required modules: Az.KeyVault, Az.Resources, EasyPIM

    .LINK
        https://github.com/yourusername/EASYPIM
    #>

# Helper functions for formatted output - add these at the beginning of your script
function Write-SectionHeader {
    param ([string]$Title)
    Write-Output "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    Write-Output "┃ $($Title.PadRight(76)) ┃"
    Write-Output "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
}

function Write-SubHeader {
    param ([string]$Title)
    Write-Output "`n▶ $Title"
    Write-Output "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"
}

function Write-GroupHeader {
    param ([string]$Title)
    # Truncate title if it's too long
    if ($Title.Length -gt 65) {
        $Title = $Title.Substring(0, 62) + "..."
    }
    $remainingLength = [Math]::Max(0, (70 - $Title.Length))
    Write-Output "`n┌─── $Title $("─" * $remainingLength)"
}

function Write-StatusSuccess {
    param ([string]$Message)
    Write-Output "✅ $Message"
}

function Write-StatusInfo {
    param ([string]$Message)
    Write-Output "ℹ️ $Message"
}

function Write-StatusProcessing {
    param ([string]$Message)
    Write-Output "⚙️ $Message"
}

function Write-StatusWarning {
    param ([string]$Message)
    Write-Warning "⚠️ $Message"
}

function Write-StatusError {
    param ([string]$Message)
    Write-Error "❌ $Message"
}

function Write-Summary {
    param (
        [string]$Category,
        [int]$Created = 0,
        [int]$Removed = 0,
        [int]$Skipped = 0,
        [int]$Failed = 0,
        [int]$Protected = 0,
        [ValidateSet("Creation", "Cleanup")]
        [string]$OperationType = "Creation"
    )
    
    Write-Output "`n┌───────────────────────────────────────────────────────────────────────────────┐"
    Write-Output "│ SUMMARY: $Category"
    Write-Output "├───────────────────────────────────────────────────────────────────────────────┤"
    
    if ($OperationType -eq "Cleanup") {
        # Use the right labels for cleanup operations
        Write-Output "│ ✅ Kept    : $Created"  # Reuse Created parameter for kept
        Write-Output "│ 🗑️ Removed : $Removed"
        Write-Output "│ ⏭️ Skipped : $Skipped"
        if ($Protected -gt 0) {
            Write-Output "│ 🛡️ Protected: $Protected"
        }
    } else {
        # Default creation display
        Write-Output "│ ✅ Created : $Created"
        Write-Output "│ ⏭️ Skipped : $Skipped"
        Write-Output "│ ❌ Failed  : $Failed"
    }
    
    Write-Output "└───────────────────────────────────────────────────────────────────────────────┘"
}

function Invoke-EasyPIMOrchestrator {
    [CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true)]
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
    
    # Initialize script-scoped counters
    $script:keptCounter = 0
    $script:removeCounter = 0 
    $script:skipCounter = 0
    $protectedCounter = 0

    # Add tracking variables for overall summary
    # Creation counters
    $overallCreated = 0
    $overallCreationSkipped = 0
    $overallFailed = 0

    # Cleanup counters
    $overallKept = 0
    $overallRemoved = 0
    $overallCleanupSkipped = 0
    
    # Display usage if no parameters are provided
    if (-not $PSBoundParameters) {
        Write-Output "Usage:"
        Write-Output "Invoke-EasyPIMOrchestrator -KeyVaultName <KeyVaultName> -SecretName <SecretName> -SubscriptionId <SubscriptionId> -TenantId <TenantId> -Mode <initial|delta>"
        Write-Output "or"
        Write-Output "Invoke-EasyPIMOrchestrator -ConfigFilePath <ConfigFilePath> -SubscriptionId <SubscriptionId> -TenantId <TenantId> -Mode <initial|delta>"
        return
    }
    
    try {
        # Import necessary modules
        Write-Output "Importing required modules..."
        Import-Module Az.KeyVault, Az.Resources
        
        
        # Retrieve the JSON config file
        Write-SectionHeader "Retrieving Configuration"
        if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            Write-Output "Reading from Key Vault '$KeyVaultName', Secret '$SecretName'"
            $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
            $jsonContent = $secret.SecretValueText | Remove-JsonComments
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'FilePath') {
            Write-Output "Reading from file '$ConfigFilePath'"
            $jsonContent = Get-Content -Path $ConfigFilePath -Raw | Remove-JsonComments
        }
        else {
            Write-Output "Please provide either KeyVault parameters or a ConfigFilePath."
            return
        }
        
        $config = $jsonContent | ConvertFrom-Json
        
        # Add a timestamp to the justification
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $justification = "Created by Invoke-EasyPIMOrchestrator at $timestamp"
        
        # Expand all assignments with PrincipalIds arrays
        $azureRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.AzureRoles
        $azureRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.AzureRolesActive
        $entraRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.EntraIDRoles
        $entraRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.EntraIDRolesActive
        $groupRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.GroupRoles
        $groupRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.GroupRolesActive

        #debug output for expanded assignments
        Write-Verbose "Expanded $($config.AzureRoles.Count) Azure role configs into $($azureRoles.Count) individual assignments"
        # Display first assignment as example
        if ($azureRoles.Count -gt 0) {
            Write-Verbose "First expanded assignment: $($azureRoles[0] | ConvertTo-Json -Compress)"
        }
        


        # Load protected users from config
        $protectedUsers = @()
        if ($config.ProtectedUsers) {
            $protectedUsers = $config.ProtectedUsers
        }
        
        #region Cleanup Logic - MOVED THIS FIRST
        Write-SectionHeader "Processing Cleanup"
        
        # Cleanup in delta mode
        if ($Mode -eq "delta") {
            Write-Output "=== Performing Delta Mode Cleanup ==="
            
            # Azure Role eligible delta cleanup
            Write-SubHeader "Azure Role Eligible Assignments Cleanup"
            if ($azureRoles) {
                $subscriptions = @($azureRoles.Scope | ForEach-Object { $_.Split("/")[2] } | Select-Object -Unique)
                
                $apiInfo = @{
                    Subscriptions = $subscriptions
                    TenantId      = $TenantId
                    RemoveCmd     = "Remove-PIMAzureResourceEligibleAssignment"
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Azure Role eligible" -ConfigAssignments $azureRoles -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "🧹Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }
            
            # Azure Role active delta cleanup
            Write-SubHeader "Azure Role Active Assignments Cleanup"
            if ($azureRolesActive) {
                $subscriptions = @($azureRolesActive.Scope | ForEach-Object { $_.Split("/")[2] } | Select-Object -Unique)
                
                $apiInfo = @{
                    Subscriptions    = $subscriptions
                    ApiEndpoint      = "https://management.azure.com/subscriptions/$($subscriptions[0])/providers/Microsoft.Authorization/roleAssignmentScheduleRequests"
                    TargetIdProperty = "targetRoleAssignmentScheduleId"
                    RemoveCmd        = "Remove-PIMAzureResourceActiveAssignment"
                    TenantId         = $TenantId
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Azure Role active" -ConfigAssignments $azureRolesActive -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }
            
            # Entra Role eligible delta cleanup
            Write-SubHeader "Entra Role Eligible Assignments Cleanup"
            if ($entraRoles) {
                $apiInfo = @{
                    Subscriptions = @()  # Not needed for Entra roles
                    RemoveCmd     = "Remove-PIMEntraRoleEligibleAssignment"
                    TenantId      = $TenantId
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Entra Role eligible" -ConfigAssignments $entraRoles -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }

            # Entra Role active delta cleanup
            Write-SubHeader "Entra Role Active Assignments Cleanup"
            if ($entraRolesActive) {
                $apiInfo = @{
                    Subscriptions = @()  # Not needed for Entra roles
                    RemoveCmd     = "Remove-PIMEntraRoleActiveAssignment"
                    TenantId      = $TenantId
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Entra Role active" -ConfigAssignments $entraRolesActive -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }

            # Group Role eligible delta cleanup
            Write-SubHeader "Group Role Eligible Assignments Cleanup"
            if ($groupRoles) {
                Write-StatusInfo "Processing Group Role eligible delta cleanup"
                
                # Get all unique group IDs
                $groupIds = $groupRoles | Select-Object -ExpandProperty GroupId -Unique
                
                # Create API info with list of all group IDs
                $apiInfo = @{
                    Subscriptions = @()  # Not needed for Group roles
                    GroupIds      = $groupIds # Pass all group IDs at once
                    RemoveCmd     = "Remove-PIMGroupEligibleAssignment"
                    TenantId      = $TenantId
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Group eligible" -ConfigAssignments $groupRoles -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }

            # Group Role active delta cleanup
            Write-SubHeader "Group Role Active Assignments Cleanup"
            if ($groupRolesActive) {
                Write-StatusInfo "Processing Group Role active delta cleanup"
                
                # Get all unique group IDs
                $groupIds = $groupRolesActive | Select-Object -ExpandProperty GroupId -Unique
                
                # Create API info with list of all group IDs
                $apiInfo = @{
                    Subscriptions = @()  # Not needed for Group roles
                    GroupIds      = $groupIds # Pass all group IDs at once
                    RemoveCmd     = "Remove-PIMGroupActiveAssignment"
                    TenantId      = $TenantId
                }
                
                # Initialize counters before each cleanup operation
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0

                $result = Invoke-DeltaCleanup -ResourceType "Group active" -ConfigAssignments $groupRolesActive -ApiInfo $apiInfo -ProtectedUsers $protectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)

                # Add debugging to verify counter values
                Write-Verbose "Cleanup results for $($result.ResourceType): Kept=$keptCounter, Removed=$removeCounter, Skipped=$skipCounter"

                # Update the overall counters
                $overallKept += $keptCounter
                $overallRemoved += $removeCounter
                $overallCleanupSkipped += $skipCounter

                Write-Verbose "Running totals: Kept=$overallKept, Removed=$overallRemoved, Skipped=$overallCleanupSkipped"
            }
            
            # For Entra ID and Group roles, we'll continue to use the PIM cmdlets directly
            # Add implementation here if needed
        }
        
        # Cleanup in initial mode
        if ($Mode -eq "initial") {
            $initialResult = Invoke-InitialCleanup -Config $config `
                -TenantId $TenantId `
                -SubscriptionId $SubscriptionId `
                -AzureRoles $azureRoles `
                -AzureRolesActive $azureRolesActive `
                -EntraRoles $entraRoles `
                -EntraRolesActive $entraRolesActive `
                -GroupRoles $groupRoles `
                -GroupRolesActive $groupRolesActive

            $overallKept += $initialResult.KeptCount
            $overallRemoved += $initialResult.RemovedCount
            $overallCleanupSkipped += $initialResult.SkippedCount
                    
            Write-Verbose "Initial cleanup results: Kept=$($initialResult.KeptCount), Removed=$($initialResult.RemovedCount), Skipped=$($initialResult.SkippedCount)"
        }
        #endregion
        
        #region Process Eligible Assignments - MOVED THIS AFTER CLEANUP
        Write-SectionHeader "Processing Eligible Assignments"
        
        # Process Azure Role eligible assignments
        if ($config.AzureRoles) {
            Write-SubHeader "Processing Azure Role Eligible Assignments"
            
            $azureRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.AzureRoles
            
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
                }
                DirectFilter = $true
            }
            
            $result = Invoke-ResourceAssignments -ResourceType "Azure Role eligible" -Assignments $azureRoles -CommandMap $commandMap
            
            Write-Summary -Category "Azure Role Eligible Assignments" -Created $result.Created -Skipped $result.Skipped -Failed $result.Failed
            
            $overallCreated += $result.Created
            $overallCreationSkipped += $result.Skipped
            $overallFailed += $result.Failed
        }
        
        # Process Entra ID Role eligible assignments
        if ($config.EntraIDRoles) {
            Write-SubHeader "Processing Entra ID Role Eligible Assignments"
            
            $entraRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.EntraIDRoles
            
            $commandMap = @{
                GetCmd       = 'Get-PIMEntraRoleEligibleAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                    roleName = $entraRoles[0].Rolename
                }
                CreateCmd    = 'New-PIMEntraRoleEligibleAssignment'
                CreateParams = @{
                    tenantID = $TenantId
                }
                DirectFilter = $true
            }
            
            # Add verbose output
            Write-Verbose "About to process $($entraRoles.Count) Entra ID Role eligible assignments"
            if ($entraRoles.Count -gt 0) {
                Write-Verbose "First Entra role: $($entraRoles[0] | ConvertTo-Json -Compress)"
            }
            $result = Invoke-ResourceAssignments -ResourceType "Entra ID Role eligible" -Assignments $entraRoles -CommandMap $commandMap
            
            Write-Summary -Category "Entra ID Role Eligible Assignments" -Created $result.Created -Skipped $result.Skipped -Failed $result.Failed
            
            $overallCreated += $result.Created
            $overallCreationSkipped += $result.Skipped
            $overallFailed += $result.Failed
        }
        
        # Process Group Role eligible assignments
        if ($config.GroupRoles) {
            Write-SectionHeader "Processing Group Role Eligible Assignments"
            
            # Expand assignments with PrincipalIds arrays
            $groupRoles = Expand-AssignmentWithPrincipalIds -Assignments $config.GroupRoles
            
            # Group roles by GroupId to minimize API calls
            $groupedAssignments = $groupRoles | Group-Object -Property GroupId
            
            $totalCreateCounter = 0
            $totalSkipCounter = 0
            $totalErrorCounter = 0
            
            foreach ($groupSet in $groupedAssignments) {
                $groupId = $groupSet.Name
                $assignments = $groupSet.Group
                
                Write-GroupHeader "Processing group: $groupId with $($assignments.Count) assignments"
                
                # First check if group exists before trying to process assignments
                if (-not (Test-PrincipalExists -PrincipalId $groupId)) {
                    Write-StatusWarning "Group $groupId does not exist, skipping all assignments"
                    $totalErrorCounter += $assignments.Count
                    continue
                }
                
                # Mark this group as processed
                $processedGroups[$groupId] = $true
                
                Write-StatusSuccess "Group $groupId exists"
                
                # Try to get existing assignments (if any)
                try {
                    $existingAssignments = Get-PIMGroupEligibleAssignment -tenantID $TenantId -groupId $groupId -ErrorAction SilentlyContinue
                    Write-StatusInfo "Found $($existingAssignments.Count) existing assignments for group"
                }
                catch {
                    # Group exists but not PIM-enabled yet, which is fine
                    Write-StatusInfo "Group not yet PIM-enabled, will be enabled when first assignment is created"
                    $existingAssignments = @()
                }
                
                # Process assignments for this group using the same function
                $result = Invoke-ResourceAssignments -ResourceType "Group Role eligible ($groupId)" -Assignments $assignments -CommandMap $commandMap
                
                # Accumulate counters
                $totalCreateCounter += $result.Created
                $totalSkipCounter += $result.Skipped
                $totalErrorCounter += $result.Failed
            }
            
            # Overall summary
            Write-Summary -Category "Group Role Eligible Assignments (Total)" -Created $totalCreateCounter -Skipped $totalSkipCounter -Failed $totalErrorCounter
            $overallCreated += $totalCreateCounter
            $overallCreationSkipped += $totalSkipCounter
            $overallFailed += $totalErrorCounter
        }
        
        #endregion
        
        #region Process Active Assignments - KEPT THIS LAST
        Write-SectionHeader "Processing Active Assignments"
        
        # Process Azure Role active assignments
        if ($config.AzureRolesActive) {
            # Expand assignments with PrincipalIds arrays
            $azureRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.AzureRolesActive
            
            # First ensure we have Rolename property consistent with other sections
            $normalizedAssignments = $azureRolesActive | ForEach-Object {
                if (!$_.Rolename -and $_.Role) {
                    $_ | Add-Member -NotePropertyName "Rolename" -NotePropertyValue $_.Role -Force -PassThru
                }
                else {
                    $_
                }
            }
            
            $commandMap = @{
                GetCmd       = 'Get-PIMAzureResourceActiveAssignment'
                GetParams    = @{
                    tenantID       = $TenantId
                    subscriptionID = $SubscriptionId
                }
                CreateCmd    = 'New-PIMAzureResourceActiveAssignment'
                CreateParams = @{
                    tenantID = $TenantId
                }
                DirectFilter = $true
            }
            
            # After getting assignments, add this debugging section
            $allAssignments = & $commandMap.GetCmd -SubscriptionId $SubscriptionId -TenantId $commandMap.GetParams.tenantID
            Write-Output "    ├─ Found $($allAssignments.Count) total current assignments"

            # Debug invalid assignments
            $invalidAssignments = $allAssignments | Where-Object { (-not $_.SubjectId) -or (-not $_.RoleName) }
            if ($invalidAssignments.Count -gt 0) {
                Write-Output "    ├─ Found $($invalidAssignments.Count) system/orphaned assignments (normal)"
                Write-Verbose "Detailed invalid assignment properties:"
                foreach ($invalid in $invalidAssignments) {
                    $invalidJson = $invalid | ConvertTo-Json -Depth 1 -Compress
                    Write-Verbose "System assignment: $invalidJson"
                }
            }

            # Invoke resource assignments
            $azureActiveResult = Invoke-ResourceAssignments -ResourceType "Azure Role active" -Assignments $normalizedAssignments -CommandMap $commandMap

            # Display summary for Azure Role active
            Write-Summary -Category "Azure Role Active Assignments" -Created $azureActiveResult.Created -Skipped $azureActiveResult.Skipped -Failed $azureActiveResult.Failed
            $overallCreated += $azureActiveResult.Created
            $overallCreationSkipped += $azureActiveResult.Skipped
            $overallFailed += $azureActiveResult.Failed
        }
        
        # Process Entra ID Role active assignments
        if ($config.EntraIDRolesActive) {
            Write-SubHeader "Processing Entra ID Role active Assignments"
            
            $entraRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.EntraIDRolesActive
            
            # Verify principals exist
            $validAssignments = $entraRolesActive | Where-Object { 
                # Verify principal exists
                $exists = Test-PrincipalExists -PrincipalId $_.PrincipalId
                if (-not $exists) {
                    Write-Warning "⚠️ Principal $($_.PrincipalId) does not exist, skipping assignment"
                    return $false
                }
                
                return $true
            }
            
            if ($validAssignments.Count -gt 0) {
                $commandMap = @{
                    GetCmd       = 'Get-PIMEntraRoleActiveAssignment'
                    GetParams    = @{
                        tenantID = $TenantId
                        roleName = $validAssignments[0].Rolename
                    }
                    CreateCmd    = 'New-PIMEntraRoleActiveAssignment'
                    CreateParams = @{
                        tenantID = $TenantId
                    }
                    DirectFilter = $true
                }
                
                $result = Invoke-ResourceAssignments -ResourceType "Entra ID Role active" -Assignments $validAssignments -CommandMap $commandMap
                
                # Display the summary
                Write-Summary -Category "Entra ID Role Active Assignments" -Created $result.Created -Skipped $result.Skipped -Failed $result.Failed
                
                $overallCreated += $result.Created
                $overallCreationSkipped += $result.Skipped
                $overallFailed += $result.Failed
            }
            else {
                Write-Output "No valid Entra ID Role active assignments found after filtering"
            }
        }

  
        
        # Process Group Role active assignments
        # Process Group Role active assignments
        if ($config.GroupRolesActive) {
            Write-SubHeader "Processing Group Role Active Assignments"
    
            $groupRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $config.GroupRolesActive
    
            # Add debugging to see the actual command
            Write-Verbose "Group Role Active command: $(Get-Command 'New-PIMGroupActiveAssignment' | Select-Object -ExpandProperty Parameters | ConvertTo-Json -Depth 1)"
    
            $commandMap = @{
                GetCmd       = 'Get-PIMGroupActiveAssignment'
                GetParams    = @{
                    tenantID = $TenantId
                    groupId  = if ($groupRolesActive.Count -gt 0) { $groupRolesActive[0].GroupId } else { "" }
                }
                CreateCmd    = 'New-PIMGroupActiveAssignment'
                CreateParams = @{
                    tenantID = $TenantId
                    # Remove roleName from here if it exists
                    # Do NOT include role here - we add it conditionally in Invoke-ResourceAssignments
                }
                DirectFilter = $true
            }
    
            # Test if the command accepts 'role' or 'roleName'
            try {
                $cmdInfo = Get-Command 'New-PIMGroupActiveAssignment'
                Write-Verbose "Command parameters: $($cmdInfo.Parameters.Keys -join ', ')"
            }
            catch {
                Write-Warning "Could not get command info: $_"
            }
    
            $result = Invoke-ResourceAssignments -ResourceType "Group Role active" -Assignments $groupRolesActive -CommandMap $commandMap
    
            Write-Summary -Category "Group Role Active Assignments" -Created $result.Created -Skipped $result.Skipped -Failed $result.Failed
        }
        
        #endregion
        
        # Add grand total summary
        Write-Output "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        Write-Output "┃ OVERALL SUMMARY                                                                ┃"
        Write-Output "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        Write-Output "┌───────────────────────────────────────────────────────────────────────────────┐"
        Write-Output "│ ASSIGNMENT CREATIONS"
        Write-Output "├───────────────────────────────────────────────────────────────────────────────┤"
        Write-Output "│ ✅ Created : $overallCreated"
        Write-Output "│ ⏭️ Skipped : $overallCreationSkipped"
        Write-Output "│ ❌ Failed  : $overallFailed"
        Write-Output "└───────────────────────────────────────────────────────────────────────────────┘"
        Write-Output "┌───────────────────────────────────────────────────────────────────────────────┐"
        Write-Output "│ CLEANUP OPERATIONS"
        Write-Output "├───────────────────────────────────────────────────────────────────────────────┤"
        Write-Output "│ ✅ Kept    : $overallKept"
        Write-Output "│ 🗑️ Removed : $overallRemoved"
        Write-Output "│ ⏭️ Skipped : $overallCleanupSkipped"
        Write-Output "└───────────────────────────────────────────────────────────────────────────────┘"

        Write-Output "=== EasyPIM orchestration completed successfully ==="
    }
    catch {
        Write-Error "❌ An error occurred: $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}