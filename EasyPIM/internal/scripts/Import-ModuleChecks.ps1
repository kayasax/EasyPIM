$__easypim_import_vp = $VerbosePreference
try {
    # Suppress verbose during import unless explicitly enabled via EASYPIM_IMPORT_DIAGNOSTICS=1
    if ($env:EASYPIM_IMPORT_DIAGNOSTICS -ne '1') { $VerbosePreference = 'SilentlyContinue' }

function Test-EasyPIMDependencies {
    <#
    .SYNOPSIS
        Validates that required modules are installed when EasyPIM is imported

    .DESCRIPTION
        Checks for required PowerShell modules and provides clear guidance
        for installing missing dependencies. This runs automatically when
        the EasyPIM module is imported.

    .OUTPUTS
        System.Boolean - Returns $true if all dependencies are met, $false otherwise
    #>
    [CmdletBinding()]
    param()

    $requiredModules = @(
        @{Name = 'Microsoft.Graph.Authentication'; MinVersion = '2.10.0'; Required = $true; Purpose = 'Entra ID authentication'},
        @{Name = 'Microsoft.Graph.Identity.Governance'; MinVersion = '2.10.0'; Required = $true; Purpose = 'PIM governance operations'},
        @{Name = 'Az.Accounts'; MinVersion = '2.13.0'; Required = $true; Purpose = 'Azure resource management and authentication'}
    )

    $missingModules = @()
    $outdatedModules = @()

    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installed) {
            $missingModules += $module
        }
        elseif ($installed.Version -lt [version]$module.MinVersion) {
            $outdatedModules += @{
                Module = $module
                CurrentVersion = $installed.Version
            }
        }
    }

    # Report missing required modules
    if ($missingModules.Count -gt 0 -or $outdatedModules.Count -gt 0) {
        Write-Warning "=========================================="
        Write-Warning "EasyPIM: Module Dependencies Check"
        Write-Warning "=========================================="

        if ($missingModules.Count -gt 0) {
            Write-Warning "Missing required modules:"
            foreach ($module in $missingModules) {
                Write-Warning "  X $($module.Name) v$($module.MinVersion)+ - $($module.Purpose)"
            }
        }

        if ($outdatedModules.Count -gt 0) {
            Write-Warning "Outdated modules (upgrade recommended):"
            foreach ($item in $outdatedModules) {
                Write-Warning "  ! $($item.Module.Name) v$($item.CurrentVersion) -> v$($item.Module.MinVersion)+ required"
            }
        }

        Write-Warning ""
        Write-Warning "To install/update all required dependencies, run:"
        Write-Warning "  Install-Module Microsoft.Graph.Authentication -MinimumVersion 2.10.0 -Scope CurrentUser -Force"
        Write-Warning "  Install-Module Microsoft.Graph.Identity.Governance -MinimumVersion 2.10.0 -Scope CurrentUser -Force"
        Write-Warning "  Install-Module Az.Accounts -MinimumVersion 2.13.0 -Scope CurrentUser -Force"
        Write-Warning ""
        Write-Warning "Or install all at once:"
        Write-Warning '  @("Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.Governance", "Az.Accounts") | ForEach-Object { Install-Module $_ -Scope CurrentUser -Force }'
        Write-Warning "=========================================="

        # Store state for functions to check
        $script:DependenciesMissing = $true
        $script:MissingModuleNames = $missingModules.Name + $outdatedModules.Module.Name

        return $false
    }
    else {
        Write-Verbose "All required PowerShell modules are installed and up-to-date"
        $script:DependenciesMissing = $false
        $script:MissingModuleNames = @()
        return $true
    }
}

function Test-AzureConnections {
    <#
    .SYNOPSIS
        Checks for active Azure and Microsoft Graph connections
    #>
    [CmdletBinding()]
    param()

    $localVerbose = $PSBoundParameters.ContainsKey('Verbose')
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue

    $connectionInfo = @{
        AzConnected = $null -ne $azContext
        MgConnected = $null -ne $mgContext
        AzEnvironment = if ($azContext) { $azContext.Environment.Name } else { $null }
        MgEnvironment = if ($mgContext) { $mgContext.Environment } else { $null }
    }

    if (-not $connectionInfo.AzConnected) {
        if ($localVerbose) { Write-Verbose "No Azure context found. Run 'Connect-AzAccount' to connect to Azure." }
    } else {
        if ($localVerbose) { Write-Verbose "Connected to Azure environment: $($connectionInfo.AzEnvironment)" }
    }

    if (-not $connectionInfo.MgConnected) {
        if ($localVerbose) { Write-Verbose "No Microsoft Graph context found. Run 'Connect-MgGraph' to connect to Microsoft Graph." }
    } else {
        if ($localVerbose) { Write-Verbose "Connected to Microsoft Graph environment: $($connectionInfo.MgEnvironment)" }
    }

    return $connectionInfo
}

# Initialize EasyPIM module (quiet by default; diagnostics opt-in via EASYPIM_IMPORT_DIAGNOSTICS=1)
if ($env:EASYPIM_IMPORT_DIAGNOSTICS -eq '1') { Write-Verbose "Initializing EasyPIM module..." }

# Check dependencies
$dependenciesValid = Test-EasyPIMDependencies

# Diagnostics are not executed during import. To run connection and endpoint checks, call Test-PIMEndpointDiscovery or set EASYPIM_IMPORT_DIAGNOSTICS=1 and run that cmdlet explicitly.
# Disable import-time diagnostics entirely; use Test-PIMEndpointDiscovery when needed
$diagnosticsOnImport = $false
if ($false) {
    # Reserved for optional future diagnostics
}

# Set module-scoped variables
$script:ModuleDependenciesValid = $dependenciesValid

if ($env:EASYPIM_IMPORT_DIAGNOSTICS -eq '1') { Write-Verbose "EasyPIM initialization complete" }

} finally {
    $VerbosePreference = $__easypim_import_vp
}
