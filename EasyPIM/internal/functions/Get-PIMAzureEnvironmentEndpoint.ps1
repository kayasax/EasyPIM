function Get-PIMAzureEnvironmentEndpoint {
    <#
    .SYNOPSIS
        Gets the correct Azure endpoint URLs based on the current Azure environment
    
    .DESCRIPTION
        Retrieves ARM and Microsoft Graph endpoints appropriate for the current Azure environment.
        Supports built-in environments (Commercial, US Government, China, Germany) and custom environments.
        For Microsoft Graph, attempts dynamic discovery via multiple methods.
    
    .PARAMETER EndpointType
        The type of endpoint to retrieve: 'ARM' or 'MicrosoftGraph'
        
    .PARAMETER NoCache
        Skip cache and force fresh endpoint discovery. Useful for testing or when environment context changes.
    
    .EXAMPLE
        Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
        Returns: https://management.azure.com/ (for Commercial cloud)
    
    .EXAMPLE
        Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
        Returns: https://graph.microsoft.com (for Commercial cloud)
        
    .EXAMPLE
        Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -NoCache
        Forces fresh discovery, bypassing cache. Useful when switching between environments.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ARM', 'MicrosoftGraph')]
        [string]$EndpointType,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoCache
    )
    
    # Cache discovered endpoints for performance, but invalidate if environment changes
    if (-not $script:EndpointCache) {
        $script:EndpointCache = @{}
    }
    
    # Track the environment for cache validation
    if (-not $script:CachedEnvironmentName) {
        $script:CachedEnvironmentName = $null
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
        
        # Clear cache if environment changed or NoCache is specified
        if ($script:CachedEnvironmentName -ne $environmentName -or $NoCache) {
            if ($script:CachedEnvironmentName -ne $environmentName) {
                Write-Verbose "Environment changed from '$script:CachedEnvironmentName' to '$environmentName'. Clearing endpoint cache."
            }
            elseif ($NoCache) {
                Write-Verbose "NoCache specified. Clearing endpoint cache."
            }
            $script:EndpointCache = @{}
            $script:CachedEnvironmentName = $environmentName
        }
        
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
                    # Validate that discovered endpoint seems appropriate for the environment
                    if (Test-EndpointEnvironmentMatch -Endpoint $endpoint -EnvironmentName $environmentName) {
                        $script:EndpointCache[$cacheKey] = $endpoint
                        return $endpoint
                    }
                    else {
                        Write-Warning "Discovered Microsoft Graph endpoint '$endpoint' doesn't appear to match environment '$environmentName'"
                    }
                }
                
                # Instead of defaulting to Commercial, fail with a clear error message
                $errorMessage = "Could not determine Microsoft Graph endpoint for environment '$environmentName'. " +
                                "Please ensure you have the correct modules installed (Microsoft.Graph.Authentication) " +
                                "and try again with -NoCache to force fresh discovery."
                Write-Error $errorMessage
                throw $errorMessage
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

function Test-EndpointEnvironmentMatch {
    <#
    .SYNOPSIS
        Validates that a discovered endpoint matches the expected Azure environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    
    # Known endpoint patterns for validation
    $environmentPatterns = @{
        'AzureCloud'        = @('graph.microsoft.com', 'management.azure.com')
        'AzureUSGovernment' = @('graph.microsoft.us', 'management.usgovcloudapi.net')
        'AzureChinaCloud'   = @('microsoftgraph.chinacloudapi.cn', 'management.chinacloudapi.cn')
        'AzureGermanCloud'  = @('graph.microsoft.de', 'management.microsoftazure.de')
    }
    
    $expectedPatterns = $environmentPatterns[$EnvironmentName]
    if (-not $expectedPatterns) {
        # For unknown environments, accept any endpoint (custom clouds)
        Write-Verbose "Unknown environment '$EnvironmentName'. Accepting endpoint '$Endpoint'"
        return $true
    }
    
    # Check if endpoint matches expected patterns for this environment
    foreach ($pattern in $expectedPatterns) {
        if ($Endpoint -like "*$pattern*") {
            Write-Verbose "Endpoint '$Endpoint' matches expected pattern '$pattern' for environment '$EnvironmentName'"
            return $true
        }
    }
    
    Write-Verbose "Endpoint '$Endpoint' doesn't match expected patterns for environment '$EnvironmentName': $($expectedPatterns -join ', ')"
    return $false
}
