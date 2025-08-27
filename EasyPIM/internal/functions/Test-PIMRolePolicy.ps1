function Test-PIMRolePolicy {
    <#
    .SYNOPSIS
    Tests PIM role policy configuration to diagnose ExpirationRule and other validation failures

    .DESCRIPTION
    This function analyzes the PIM role policy settings and identifies potential issues that could cause
    validation failures when creating active role assignments.

    .PARAMETER RoleName
    The name of the role to analyze (e.g., "User Administrator")

    .PARAMETER TenantID
    The tenant ID to connect to

    .EXAMPLE
    Test-PIMRolePolicy -RoleName "User Administrator" -TenantID "your-tenant-id"
    #>

    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$TenantID
    )

    try {
        Write-Host "=== PIM Role Policy Diagnostics for '$RoleName' ===" -ForegroundColor Cyan

        # Connect to Microsoft Graph
        Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' -NoWelcome

        # Get role definition
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$RoleName'"
        if (-not $roleDefinition) {
            throw "Role '$RoleName' not found"
        }

        $roleDefId = $roleDefinition[0].Id
        Write-Host "✅ Role found: $RoleName (ID: $roleDefId)" -ForegroundColor Green

        # Get role policy
        $rolePolicy = Get-MgRoleManagementDirectoryRoleAssignmentPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleDefId'"
        $policyId = $rolePolicy[0].Id
        Write-Host "✅ Policy found: $policyId" -ForegroundColor Green

        # Get all policy rules
        $policyRules = Get-MgRoleManagementDirectoryRoleAssignmentPolicyRule -UnifiedRoleManagementPolicyId $policyId

        Write-Host "`n🔍 Analyzing Policy Rules..." -ForegroundColor Yellow

        # Check each critical rule
        $issues = @()
        $recommendations = @()

        # 1. Expiration Rule for Admin Assignment
        $expirationRule = $policyRules | Where-Object { $_.Id -eq "Expiration_Admin_Assignment" }
        if ($expirationRule) {
            $maxDuration = $expirationRule.AdditionalProperties.maximumDuration
            $isRequired = $expirationRule.AdditionalProperties.isExpirationRequired

            Write-Host "`n⏰ Expiration_Admin_Assignment:" -ForegroundColor Green
            Write-Host "   Maximum Duration: '$maxDuration'" -ForegroundColor White
            Write-Host "   Expiration Required: $isRequired" -ForegroundColor White

            if ($maxDuration -eq "PT0S") {
                $issues += "❌ CRITICAL: MaximumActiveAssignmentDuration is PT0S (zero duration) - this WILL cause ExpirationRule failures"
                $recommendations += "🔧 URGENT: Change MaximumActiveAssignmentDuration to a reasonable value like P365D in Azure Portal"
                $recommendations += "📍 Path: Azure Portal > Microsoft Entra ID > PIM > Roles > $RoleName > Role settings > Assignment tab"
            }

            if ($maxDuration -and $maxDuration -ne "PT0S") {
                try {
                    $maxTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($maxDuration)
                    if ($maxTimeSpan.TotalHours -lt 1) {
                        $issues += "Maximum duration ($maxDuration) is less than 1 hour - requests for PT1H will fail"
                        $recommendations += "Use shorter durations like PT30M or PT45M for this role"
                    }
                } catch {
                    $issues += "Could not parse maximum duration format: $maxDuration"
                }
            }
        }

        # 2. Enablement Rule for Admin Assignment
        $enablementRule = $policyRules | Where-Object { $_.Id -eq "Enablement_Admin_Assignment" }
        if ($enablementRule) {
            $enabledRules = $enablementRule.AdditionalProperties.enabledRules

            Write-Host "`n🔐 Enablement_Admin_Assignment:" -ForegroundColor Green
            Write-Host "   Enabled Rules: $($enabledRules -join ', ')" -ForegroundColor White

            if ($enabledRules -contains "Ticketing") {
                Write-Host "   ⚠️  Ticketing is REQUIRED - ticketInfo must be provided" -ForegroundColor Yellow
            }
            if ($enabledRules -contains "Justification") {
                Write-Host "   ℹ️  Justification is required" -ForegroundColor Cyan
            }
            if ($enabledRules -contains "MultiFactorAuthentication") {
                Write-Host "   🔐 MFA is required" -ForegroundColor Cyan
            }
        }

        # 3. Approval Rule for Admin Assignment
        $approvalRule = $policyRules | Where-Object { $_.Id -eq "Approval_Admin_Assignment" }
        if ($approvalRule) {
            $approvalSettings = $approvalRule.AdditionalProperties.setting

            Write-Host "`n📋 Approval_Admin_Assignment:" -ForegroundColor Green

            if ($approvalSettings -and $approvalSettings.isApprovalRequired) {
                Write-Host "   ❌ APPROVAL IS REQUIRED - this may cause immediate failures" -ForegroundColor Red
                $issues += "Role requires approval for admin assignments - requests will not complete immediately"
                $recommendations += "Consider using selfActivate action instead of adminAssign, or disable approval requirement"
            } else {
                Write-Host "   ✅ No approval required" -ForegroundColor Green
            }
        }

        # Summary
        Write-Host "`n📊 Diagnostic Summary:" -ForegroundColor Yellow

        if ($issues.Count -gt 0) {
            Write-Host "`n⚠️  Issues Found:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "   • $_" -ForegroundColor White }
        } else {
            Write-Host "   ✅ No major policy issues detected" -ForegroundColor Green
        }

        if ($recommendations.Count -gt 0) {
            Write-Host "`n💡 Recommendations:" -ForegroundColor Cyan
            $recommendations | ForEach-Object { Write-Host "   • $_" -ForegroundColor White }
        }

        Write-Host "`n🚀 Suggested Test Command:" -ForegroundColor Yellow
        if ($maxDuration -and $maxDuration -ne "PT0S") {
            Write-Host "   New-PIMEntraRoleActiveAssignment -RoleName '$RoleName' -Duration '$maxDuration' -PrincipalName 'user@domain.com'" -ForegroundColor White
        } else {
            Write-Host "   New-PIMEntraRoleActiveAssignment -RoleName '$RoleName' -Duration 'PT30M' -PrincipalName 'user@domain.com'" -ForegroundColor White
        }

    } catch {
        Write-Error "Error in Test-PIMRolePolicy: $($_.Exception.Message)"
    }
}

# Export the function
Export-ModuleMember -Function Test-PIMRolePolicy
