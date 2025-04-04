function Initialize-EasyPIMAssignments {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    # Generate standard justification
    $justification = Get-EasyPIMJustification -IncludeTimestamp
    
    # Initialize the processed config
    $processedConfig = [PSCustomObject]@{
        AzureRoles = @()
        AzureRolesActive = @()
        EntraIDRoles = @()
        EntraIDRolesActive = @()
        GroupRoles = @()
        GroupRolesActive = @()
        ProtectedUsers = @()
        Justification = $justification  # Store for reference
    }
    
    # Expand all assignments with PrincipalIds arrays
    if ($Config.AzureRoles) {
        $processedConfig.AzureRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.AzureRoles
        Write-Verbose "Expanded $($Config.AzureRoles.Count) Azure role configs into $($processedConfig.AzureRoles.Count) individual assignments"
    }
    
    if ($Config.AzureRolesActive) {
        $processedConfig.AzureRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.AzureRolesActive
        
        # Ensure RoleName is consistent (some use Role instead)
        $processedConfig.AzureRolesActive = $processedConfig.AzureRolesActive | ForEach-Object {
            if (!$_.Rolename -and $_.Role) {
                $_ | Add-Member -NotePropertyName "Rolename" -NotePropertyValue $_.Role -Force -PassThru
            } else {
                $_
            }
        }
    }
    
    if ($Config.EntraIDRoles) {
        $processedConfig.EntraIDRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.EntraIDRoles
    }
    
    if ($Config.EntraIDRolesActive) {
        $processedConfig.EntraIDRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.EntraIDRolesActive
    }
    
    if ($Config.GroupRoles) {
        $processedConfig.GroupRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.GroupRoles
    }
    
    if ($Config.GroupRolesActive) {
        $processedConfig.GroupRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.GroupRolesActive
    }
    
    # Copy protected users
    if ($Config.ProtectedUsers) {
        $processedConfig.ProtectedUsers = $Config.ProtectedUsers
    }
    
    return $processedConfig
}