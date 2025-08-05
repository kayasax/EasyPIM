function New-EasyPIMPolicies {
    <#
    .SYNOPSIS
        Applies PIM policy configurations from the processed configuration.
    
    .DESCRIPTION
        This function applies policy configurations for Azure Resources, Entra Roles, and Groups
        using the existing Import-PIM*Policy functions.
    
    .PARAMETER Config
        The processed configuration object containing resolved policy definitions
    
    .PARAMETER TenantId
        The Azure AD tenant ID
    
    .PARAMETER SubscriptionId
        The Azure subscription ID (required for Azure role policies)
    
    .PARAMETER PolicyMode
        The policy application mode: validate, delta, or initial
    
    .EXAMPLE
        $results = New-EasyPIMPolicies -Config $processedConfig -TenantId $tenantId -SubscriptionId $subscriptionId
    
    .NOTES
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("validate", "delta", "initial")]
        [string]$PolicyMode = "validate"
    )

    Write-Verbose "Starting New-EasyPIMPolicies in $PolicyMode mode"
    
    $results = @{
        AzureRolePolicies = @()
        EntraRolePolicies = @()
        GroupPolicies = @()
        Errors = @()
        Summary = @{
            TotalProcessed = 0
            Successful = 0
            Failed = 0
            Skipped = 0
        }
    }

    try {
        # Process Azure Role Policies
        if ($Config.ContainsKey('AzureRolePolicies') -and $Config.AzureRolePolicies.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("Azure Role Policies", "Process $($Config.AzureRolePolicies.Count) policies")) {
                Write-Host "🔧 Processing Azure Role Policies..." -ForegroundColor Cyan
                
                if (-not $SubscriptionId) {
                    $errorMsg = "SubscriptionId is required for Azure Role Policies"
                    Write-Error $errorMsg
                    $results.Errors += $errorMsg
                }
                else {
                    foreach ($policyDef in $Config.AzureRolePolicies) {
                        $results.Summary.TotalProcessed++
                        
                        try {
                            $policyResult = Set-AzureRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -SubscriptionId $SubscriptionId -Mode $PolicyMode
                            $results.AzureRolePolicies += $policyResult
                            $results.Summary.Successful++
                            
                            Write-Host "  ✅ Applied policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)'" -ForegroundColor Green
                        }
                        catch {
                            $errorMsg = "Failed to apply Azure role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"
                            Write-Error $errorMsg
                            $results.Errors += $errorMsg
                            $results.Summary.Failed++
                        }
                    }
                }
            } else {
                Write-Host "⚠️ Skipping Azure Role Policies processing due to WhatIf" -ForegroundColor Yellow
                $results.Summary.Skipped += $Config.AzureRolePolicies.Count
            }
        }

        # Process Entra Role Policies
        if ($Config.ContainsKey('EntraRolePolicies') -and $Config.EntraRolePolicies.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("Entra Role Policies", "Process $($Config.EntraRolePolicies.Count) policies")) {
                Write-Host "🔧 Processing Entra Role Policies..." -ForegroundColor Cyan
                
                foreach ($policyDef in $Config.EntraRolePolicies) {
                    $results.Summary.TotalProcessed++
                    
                    try {
                        $policyResult = Set-EntraRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode
                        $results.EntraRolePolicies += $policyResult
                        $results.Summary.Successful++
                        
                        Write-Host "  ✅ Applied policy for Entra role '$($policyDef.RoleName)'" -ForegroundColor Green
                    }
                    catch {
                        $errorMsg = "Failed to apply Entra role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"
                        Write-Error $errorMsg
                        $results.Errors += $errorMsg
                        $results.Summary.Failed++
                    }
                }
            } else {
                Write-Host "⚠️ Skipping Entra Role Policies processing due to WhatIf" -ForegroundColor Yellow
                $results.Summary.Skipped += $Config.EntraRolePolicies.Count
            }
        }

        # Process Group Policies
        if ($Config.ContainsKey('GroupPolicies') -and $Config.GroupPolicies.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("Group Policies", "Process $($Config.GroupPolicies.Count) policies")) {
                Write-Host "🔧 Processing Group Policies..." -ForegroundColor Cyan
                
                foreach ($policyDef in $Config.GroupPolicies) {
                    $results.Summary.TotalProcessed++
                    
                    try {
                        $policyResult = Set-GroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode
                        $results.GroupPolicies += $policyResult
                        $results.Summary.Successful++
                        
                        Write-Host "  ✅ Applied policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)'" -ForegroundColor Green
                    }
                    catch {
                        $errorMsg = "Failed to apply Group policy for '$($policyDef.GroupId)' role '$($policyDef.RoleName)': $($_.Exception.Message)"
                        Write-Error $errorMsg
                        $results.Errors += $errorMsg
                        $results.Summary.Failed++
                    }
                }
            } else {
                Write-Host "⚠️ Skipping Group Policies processing due to WhatIf" -ForegroundColor Yellow
                $results.Summary.Skipped += $Config.GroupPolicies.Count
            }
        }

        Write-Verbose "New-EasyPIMPolicies completed. Processed: $($results.Summary.TotalProcessed), Successful: $($results.Summary.Successful), Failed: $($results.Summary.Failed)"
        return $results
    }
    catch {
        Write-Error "Failed to process PIM policies: $($_.Exception.Message)"
        throw
    }
}

function Set-AzureRolePolicy {
    <#
    .SYNOPSIS
        Applies a single Azure role policy.
    
    .DESCRIPTION
        This function applies an Azure role policy by converting the policy definition to CSV format
        and using the existing Import-PIMAzureResourcePolicy function.
    
    .PARAMETER PolicyDefinition
        The resolved policy definition
    
    .PARAMETER TenantId
        The Azure AD tenant ID
    
    .PARAMETER SubscriptionId
        The Azure subscription ID
    
    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyDefinition,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Azure role policy for $($PolicyDefinition.RoleName) at $($PolicyDefinition.Scope)"
    
    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for role '$($PolicyDefinition.RoleName)'"
        return @{
            RoleName = $PolicyDefinition.RoleName
            Scope = $PolicyDefinition.Scope
            Status = "Validated"
            Mode = $Mode
        }
    }

    # Convert policy to CSV format and create temporary file
    $csvData = ConvertTo-PolicyCSV -Policy $PolicyDefinition.ResolvedPolicy -PolicyType "AzureRole" -RoleName $PolicyDefinition.RoleName -Scope $PolicyDefinition.Scope
    $tempCsvPath = [System.IO.Path]::GetTempFileName() + ".csv"
    
    try {
        $csvData | Export-Csv -Path $tempCsvPath -NoTypeInformation
        
        if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "Apply policy")) {
            # Use existing Import-PIMAzureResourcePolicy function
            Import-PIMAzureResourcePolicy -subscriptionID $SubscriptionId -tenantID $TenantId -path $tempCsvPath
        }
        
        return @{
            RoleName = $PolicyDefinition.RoleName
            Scope = $PolicyDefinition.Scope
            Status = "Applied"
            Mode = $Mode
        }
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempCsvPath) {
            Remove-Item $tempCsvPath -Force
        }
    }
}

function Set-EntraRolePolicy {
    <#
    .SYNOPSIS
        Applies a single Entra role policy.
    
    .DESCRIPTION
        This function applies an Entra role policy by converting the policy definition to CSV format
        and using the existing Import-PIMEntraRolePolicy function.
    
    .PARAMETER PolicyDefinition
        The resolved policy definition
    
    .PARAMETER TenantId
        The Azure AD tenant ID
    
    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyDefinition,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Entra role policy for $($PolicyDefinition.RoleName)"
    
    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for Entra role '$($PolicyDefinition.RoleName)'"
        return @{
            RoleName = $PolicyDefinition.RoleName
            Status = "Validated"
            Mode = $Mode
        }
    }

    # Convert policy to CSV format and create temporary file
    $csvData = ConvertTo-PolicyCSV -Policy $PolicyDefinition.ResolvedPolicy -PolicyType "EntraRole" -RoleName $PolicyDefinition.RoleName
    $tempCsvPath = [System.IO.Path]::GetTempFileName() + ".csv"
    
    try {
        $csvData | Export-Csv -Path $tempCsvPath -NoTypeInformation
        
        if ($PSCmdlet.ShouldProcess("Entra role policy for $($PolicyDefinition.RoleName)", "Apply policy")) {
            # Use existing Import-PIMEntraRolePolicy function
            Import-PIMEntraRolePolicy -tenantID $TenantId -path $tempCsvPath
        }
        
        return @{
            RoleName = $PolicyDefinition.RoleName
            Status = "Applied"
            Mode = $Mode
        }
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempCsvPath) {
            Remove-Item $tempCsvPath -Force
        }
    }
}

function Set-GroupPolicy {
    <#
    .SYNOPSIS
        Applies a single Group policy.
    
    .DESCRIPTION
        This function applies a Group policy. Note: Group policy import functionality
        may need to be implemented if not available in existing functions.
    
    .PARAMETER PolicyDefinition
        The resolved policy definition
    
    .PARAMETER TenantId
        The Azure AD tenant ID
    
    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyDefinition,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Group policy for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)"
    
    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for Group '$($PolicyDefinition.GroupId)' role '$($PolicyDefinition.RoleName)'"
        return @{
            GroupId = $PolicyDefinition.GroupId
            RoleName = $PolicyDefinition.RoleName
            Status = "Validated"
            Mode = $Mode
        }
    }

    # Note: Group policy import may need additional implementation
    # For now, we'll use Set-PIMGroupPolicy if available
    if ($PSCmdlet.ShouldProcess("Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)", "Apply policy")) {
        Write-Warning "Group policy application is not yet fully implemented. Policy would be applied for Group '$($PolicyDefinition.GroupId)' role '$($PolicyDefinition.RoleName)'"
    }
    
    return @{
        GroupId = $PolicyDefinition.GroupId
        RoleName = $PolicyDefinition.RoleName
        Status = "Pending Implementation"
        Mode = $Mode
    }
}

function ConvertTo-PolicyCSV {
    <#
    .SYNOPSIS
        Converts a policy object to CSV format for use with existing Import-PIM*Policy functions.
    
    .DESCRIPTION
        This function converts an inline policy object to the CSV format expected by the existing
        Import-PIMAzureResourcePolicy and Import-PIMEntraRolePolicy functions.
    
    .PARAMETER Policy
        The policy object to convert
    
    .PARAMETER PolicyType
        The type of policy (AzureRole, EntraRole, Group)
    
    .PARAMETER RoleName
        The role name
    
    .PARAMETER Scope
        The scope (for Azure roles)
    
    .EXAMPLE
        $csvData = ConvertTo-PolicyCSV -Policy $policy -PolicyType "AzureRole" -RoleName "Owner" -Scope "/subscriptions/..."
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Policy,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("AzureRole", "EntraRole", "Group")]
        [string]$PolicyType,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleName,
        
        [Parameter(Mandatory = $false)]
        [string]$Scope
    )

    Write-Verbose "Converting policy to CSV format for $PolicyType"
    
    # Create CSV row object
    $csvRow = [PSCustomObject]@{
        RoleName = $RoleName
        ActivationDuration = $Policy.ActivationDuration
        EnablementRules = ($Policy.EnablementRules -join ',')
        ApprovalRequired = $Policy.ApprovalRequired.ToString()
        Approvers = ($Policy.Approvers | ConvertTo-Json -Compress)
        AllowPermanentEligibleAssignment = $Policy.AllowPermanentEligibleAssignment.ToString()
        MaximumEligibleAssignmentDuration = $Policy.MaximumEligibleAssignmentDuration
        AllowPermanentActiveAssignment = $Policy.AllowPermanentActiveAssignment.ToString()
        MaximumActiveAssignmentDuration = $Policy.MaximumActiveAssignmentDuration
    }

    # Add scope for Azure roles
    if ($PolicyType -eq "AzureRole" -and $Scope) {
        $csvRow | Add-Member -NotePropertyName "Scope" -NotePropertyValue $Scope
    }

    # Add notification settings if they exist
    if ($Policy.Notifications) {
        $notifications = $Policy.Notifications
        
        # Eligibility notifications
        if ($notifications.Eligibility) {
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_Recipients" -NotePropertyValue ($notifications.Eligibility.Alert.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_Recipients" -NotePropertyValue ($notifications.Eligibility.Assignee.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_Recipients" -NotePropertyValue ($notifications.Eligibility.Approvers.Recipients -join ',')
        }
        
        # Active notifications
        if ($notifications.Active) {
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_NotificationLevel" -NotePropertyValue $notifications.Active.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_Recipients" -NotePropertyValue ($notifications.Active.Alert.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_NotificationLevel" -NotePropertyValue $notifications.Active.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_Recipients" -NotePropertyValue ($notifications.Active.Assignee.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_NotificationLevel" -NotePropertyValue $notifications.Active.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_Recipients" -NotePropertyValue ($notifications.Active.Approvers.Recipients -join ',')
        }
        
        # Activation notifications
        if ($notifications.Activation) {
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_NotificationLevel" -NotePropertyValue $notifications.Activation.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_Recipients" -NotePropertyValue ($notifications.Activation.Alert.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_NotificationLevel" -NotePropertyValue $notifications.Activation.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_Recipients" -NotePropertyValue ($notifications.Activation.Assignee.Recipients -join ',')
            
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_NotificationLevel" -NotePropertyValue $notifications.Activation.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_Recipients" -NotePropertyValue ($notifications.Activation.Approvers.Recipients -join ',')
        }
    }

    Write-Verbose "Policy conversion to CSV completed"
    return @($csvRow)
}
