function Get-AzureEnvironmentEndpoint {
    <#
    .SYNOPSIS
        Gets the correct Azure endpoint URLs based on the current Azure environment
    
    .DESCRIPTION
        Retrieves ARM and Microsoft Graph endpoints appropriate for the current Azure environment.
        Supports built-in environments (Commercial, US Government, China, Germany) and custom environments.
        For Microsoft Graph, attempts dynamic discovery via multiple methods.
    
    .PARAMETER EndpointType
        The type of endpoint to retrieve: 'ARM' or 'MicrosoftGraph'
    
    .EXAMPLE
        Get-AzureEnvironmentEndpoint -EndpointType 'ARM'
        Returns: https://management.azure.com/ (for Commercial cloud)
    
    .EXAMPLE
        Get-AzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
        Returns: https://graph.microsoft.com (for Commercial cloud)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ARM', 'MicrosoftGraph')]
        [string]$EndpointType
    )
    
    # Cache discovered endpoints for performance
    if (-not $script:EndpointCache) {
        $script:EndpointCache = @{}
    }
    
    try {
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        
        if ($null -eq $azContext) {
            Write-Warning "No Azure context found. Please run Connect-AzAccount first."
            throw "Azure context required for endpoint discovery"
        }
        
        $environment = $azContext.Environment
        $environmentName = $environment.Name
        Write-Verbose "Detected Azure environment: $environmentName"
        
        switch ($EndpointType) {
            'ARM' {
                # Use Az.Accounts built-in environment info
                $endpoint = $environment.ResourceManagerUrl
                
                # Ensure trailing slash for consistency
                if (-not $endpoint.EndsWith('/')) {
                    $endpoint += '/'
                }
                
                Write-Verbose "ARM endpoint from Az context: $endpoint"
                return $endpoint
            }
            
            'MicrosoftGraph' {
                # Check cache first
                $cacheKey = "MSGraph_$environmentName"
                if ($script:EndpointCache.ContainsKey($cacheKey)) {
                    Write-Verbose "Using cached Microsoft Graph endpoint for $environmentName"
                    return $script:EndpointCache[$cacheKey]
                }
                
                # Try multiple discovery methods
                $endpoint = Get-MicrosoftGraphEndpoint -EnvironmentName $environmentName -Environment $environment
                
                if ($endpoint) {
                    $script:EndpointCache[$cacheKey] = $endpoint
                    return $endpoint
                }
                
                # Fallback - this should rarely happen
                Write-Warning "Could not determine Microsoft Graph endpoint for '$environmentName'. Using Commercial endpoint as fallback."
                return 'https://graph.microsoft.com'
            }
        }
    }
    catch {
        Write-Error "Failed to get Azure environment endpoint: $_"
        throw
    }
}

function Get-MicrosoftGraphEndpoint {
    <#
    .SYNOPSIS
        Discovers Microsoft Graph endpoint for the current environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory = $true)]
        $Environment
    )
    
    # Method 1: Check if we have an active Microsoft Graph session
    try {
        $mgContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($mgContext) {
            $mgEnvironment = Get-MgEnvironment -Name $mgContext.Environment -ErrorAction SilentlyContinue
            if ($mgEnvironment -and $mgEnvironment.GraphEndpoint) {
                $endpoint = $mgEnvironment.GraphEndpoint
                if ($endpoint.EndsWith('/')) {
                    $endpoint = $endpoint.TrimEnd('/')
                }
                Write-Verbose "Microsoft Graph endpoint from active MgContext: $endpoint"
                return $endpoint
            }
        }
    }
    catch {
        Write-Verbose "Could not get Graph endpoint from active session: $_"
    }
    
    # Method 2: Map known Azure environments to Graph environments
    $graphEnvironmentMapping = @{
        'AzureCloud'        = 'Global'
        'AzureUSGovernment' = 'USGov'  
        'AzureChinaCloud'   = 'China'
        'AzureGermanCloud'  = 'Germany'
    }
    
    $graphEnvName = $graphEnvironmentMapping[$EnvironmentName]
    if ($graphEnvName) {
        try {
            $mgEnvironment = Get-MgEnvironment -Name $graphEnvName -ErrorAction SilentlyContinue
            if ($mgEnvironment -and $mgEnvironment.GraphEndpoint) {
                $endpoint = $mgEnvironment.GraphEndpoint
                if ($endpoint.EndsWith('/')) {
                    $endpoint = $endpoint.TrimEnd('/')
                }
                Write-Verbose "Microsoft Graph endpoint from MgEnvironment: $endpoint"
                return $endpoint
            }
        }
        catch {
            Write-Verbose "Could not get Graph environment for $graphEnvName`: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Check for custom environment configuration
    $customEndpoint = Get-CustomGraphEndpoint -EnvironmentName $EnvironmentName
    if ($customEndpoint) {
        Write-Verbose "Microsoft Graph endpoint from custom configuration: $customEndpoint"
        return $customEndpoint
    }
    
    # Method 4: Try to infer from Azure AD authority
    $inferredEndpoint = Get-InferredMicrosoftGraphEndpoint -Authority $Environment.ActiveDirectoryAuthority -EnvironmentName $EnvironmentName
    if ($inferredEndpoint) {
        Write-Verbose "Inferred Microsoft Graph endpoint: $inferredEndpoint"
        return $inferredEndpoint
    }
    
    return $null
}

function Get-CustomGraphEndpoint {
    <#
    .SYNOPSIS
        Gets Microsoft Graph endpoint from custom configuration sources
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    
    # Check environment variable first
    $envVarName = "EASYPIM_GRAPH_ENDPOINT_$($EnvironmentName.ToUpper() -replace '[^A-Z0-9]', '_')"
    $envValue = [System.Environment]::GetEnvironmentVariable($envVarName)
    if ($envValue) {
        Write-Verbose "Found Graph endpoint in environment variable: $envVarName"
        return $envValue.TrimEnd('/')
    }
    
    # Check configuration file
    $configPath = Join-Path $PSScriptRoot "..\configurations\custom-environments.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($config.environments.$EnvironmentName.graphEndpoint) {
                Write-Verbose "Found Graph endpoint in configuration file"
                return $config.environments.$EnvironmentName.graphEndpoint.TrimEnd('/')
            }
        }
        catch {
            Write-Verbose "Failed to read custom environment config: $_"
        }
    }
    
    return $null
}

function Get-InferredMicrosoftGraphEndpoint {
    <#
    .SYNOPSIS
        Infers Microsoft Graph endpoint based on Azure AD authority patterns
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Authority,
        
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    
    # Check if there are any custom Graph environments registered
    try {
        $allGraphEnvironments = Get-MgEnvironment -ErrorAction SilentlyContinue
        $customEnv = $allGraphEnvironments | Where-Object { 
            $_.Name -eq $EnvironmentName -or 
            ($_.AzureADEndpoint -and $_.AzureADEndpoint.TrimEnd('/') -eq $Authority.TrimEnd('/'))
        }
        
        if ($customEnv -and $customEnv.GraphEndpoint) {
            return $customEnv.GraphEndpoint.TrimEnd('/')
        }
    }
    catch {
        Write-Verbose "Could not query Microsoft Graph environments: $_"
    }
    
    # Known authority to Graph endpoint mappings for standard clouds
    $authorityMappings = @{
        'login.microsoftonline.com'     = 'https://graph.microsoft.com'
        'login.microsoftonline.us'      = 'https://graph.microsoft.us'
        'login.chinacloudapi.cn'        = 'https://microsoftgraph.chinacloudapi.cn'
        'login.partner.microsoftonline.cn' = 'https://microsoftgraph.chinacloudapi.cn'
        'login.microsoftonline.de'      = 'https://graph.microsoft.de'
    }
    
    foreach ($knownAuthority in $authorityMappings.Keys) {
        if ($Authority -like "*$knownAuthority*") {
            return $authorityMappings[$knownAuthority]
        }
    }
    
    # Try pattern-based inference for Azure Stack and private clouds
    if ($Authority -like "*azurestack*" -or $Authority -like "*stack.*") {
        # Try replacing login with graph
        $graphEndpoint = $Authority -replace 'login\.', 'graph.'
        if ($graphEndpoint -ne $Authority) {
            Write-Verbose "Inferred Azure Stack Graph endpoint: $graphEndpoint"
            return $graphEndpoint.TrimEnd('/')
        }
    }
    
    return $null
}
