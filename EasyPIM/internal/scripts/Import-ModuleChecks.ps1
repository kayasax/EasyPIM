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
    
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    
    $connectionInfo = @{
        AzConnected = $null -ne $azContext
        MgConnected = $null -ne $mgContext
        AzEnvironment = if ($azContext) { $azContext.Environment.Name } else { $null }
        MgEnvironment = if ($mgContext) { $mgContext.Environment } else { $null }
    }
    
    if (-not $connectionInfo.AzConnected) {
        Write-Verbose "No Azure context found. Run 'Connect-AzAccount' to connect to Azure."
    } else {
        Write-Verbose "Connected to Azure environment: $($connectionInfo.AzEnvironment)"
    }
    
    if (-not $connectionInfo.MgConnected) {
        Write-Verbose "No Microsoft Graph context found. Run 'Connect-MgGraph' to connect to Microsoft Graph."
    } else {
        Write-Verbose "Connected to Microsoft Graph environment: $($connectionInfo.MgEnvironment)"
    }
    
    return $connectionInfo
}

# Initialize EasyPIM module
Write-Verbose "Initializing EasyPIM module..."

# Check dependencies
$dependenciesValid = Test-EasyPIMDependencies

# Check connections (verbose output only)
$VerbosePreference_Original = $VerbosePreference
try {
    if ($dependenciesValid) {
        $VerbosePreference = 'Continue'
        $connectionInfo = Test-AzureConnections
        
        # Test endpoint discovery if connected
        if ($connectionInfo.AzConnected) {
            try {
                # Import the endpoint function
                . "$PSScriptRoot\..\..\functions\Get-AzureEnvironmentEndpoint.ps1"
                
                $armEndpoint = Get-AzureEnvironmentEndpoint -EndpointType 'ARM' -ErrorAction SilentlyContinue
                $graphEndpoint = Get-AzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -ErrorAction SilentlyContinue
                
                Write-Verbose "Endpoint configuration:"
                Write-Verbose "  ARM: $armEndpoint"
                Write-Verbose "  Graph: $graphEndpoint"
            }
            catch {
                Write-Verbose "Endpoint discovery will be performed on first use"
            }
        }
    }
}
finally {
    $VerbosePreference = $VerbosePreference_Original
}

# Set module-scoped variables
$script:ModuleDependenciesValid = $dependenciesValid

Write-Verbose "EasyPIM initialization complete"
