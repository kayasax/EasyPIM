<#
      .Synopsis
       invoke Microsoft Graph API
      .Description
       wrapper function to get an access token and set authentication header for each ARM API call.
       For GET requests, automatically handles pagination by collecting results from all pages.
      .Parameter Endpoint
       the Graph endpoint
      .Parameter Method
       http method to use
      .Parameter version
       the Graph API version to use (default: v1.0)
      .Parameter Body
       an optional body
      .Parameter Filter
       an optional OData filter string to apply to the request
      .Parameter NoPagination
       if specified, disables automatic pagination for GET requests      .Example
        PS> invoke-Graph -Endpoint "users" -Method "GET"

        will send a GET query to the users endpoint and return all results (handling pagination automatically)

      .Example
        PS> invoke-Graph -Endpoint "users?`$top=10" -Method "GET" -NoPagination

        will send a GET query and return only the first page of results

      .Example
        PS> invoke-Graph -Endpoint "users" -Method "GET" -Filter "displayName eq 'John Doe'"

        will send a GET query to the users endpoint with a filter for displayName equals 'John Doe'

      .Example
        PS> invoke-Graph -Endpoint "users?`$filter=userType eq 'Member'" -Method "GET" -Filter "accountEnabled eq true"

        will combine filters using 'and' operator, resulting in: userType eq 'Member' and accountEnabled eq true
      .Link

      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function invoke-graph {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [String]
        $Endpoint,
        [String]
        $Method = "GET",
        [String]
        $version = "v1.0",
        [String]
        $body,
        [String]
        $Filter,
        [switch]
        $NoPagination
    )

    try {
        $graphBase = Get-AzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
        $graph = "$graphBase/$version/"

        [string]$uri = $graph + $endpoint        # Handle filter parameter
        if (-not [string]::IsNullOrEmpty($Filter)) {
            if ($uri -like "*`$filter=*") {
                # URI already contains a filter, combine them with 'and'
                $uri = $uri -replace "(\`$filter=[^&]*)", "`$1 and $Filter"
            }
            elseif ($uri.Contains("?")) {
                # URI has query parameters but no filter, add filter parameter
                $uri += "&`$filter=$Filter"
            }
            else {
                # URI has no query parameters, add filter as first parameter
                $uri += "?`$filter=$Filter"
            }
        }

        Write-Verbose "uri = $uri"

        # Resolve tenantId from multiple potential scopes (module script scope, global, environment) to support external validator scripts
        $tenantPref = $script:tenantID
        if(-not $tenantPref){
            $gv = Get-Variable -Name tenantID -Scope Global -ErrorAction SilentlyContinue
            if($gv){ $tenantPref = $gv.Value }
        }
        if(-not $tenantPref -and $env:TENANTID){ $tenantPref = $env:TENANTID }
        if(-not $tenantPref){ Write-Verbose "No tenantID resolved; proceeding will likely fail authentication" }
        if ( $null -eq (get-mgcontext) -or ( (get-mgcontext).TenantId -ne $tenantPref ) ) {
            Write-Verbose ">> Connecting to Azure with tenantID $tenantPref"
            $scopes = @(
                "RoleManagementPolicy.ReadWrite.Directory",
                "PrivilegedAccess.ReadWrite.AzureAD",
                "RoleManagement.ReadWrite.Directory",
                "RoleManagementPolicy.ReadWrite.AzureADGroup",
                "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
                "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
                "PrivilegedAccess.ReadWrite.AzureADGroup",
                "AuditLog.Read.All",
                "Directory.Read.All")

            if($tenantPref){ Connect-MgGraph -Tenant $tenantPref -Scopes $scopes -NoWelcome } else { Connect-MgGraph -Scopes $scopes -NoWelcome }
        }

        # Handle pagination if needed (for GET requests only)
        if ($Method -eq "GET" -and -not $NoPagination) {
            $allResults = @()
            $currentUri = $uri
            $hasMorePages = $true

            while ($hasMorePages) {
                Write-Verbose "Fetching data from: $currentUri"

                try {
                    $response = Invoke-MgGraphRequest -Uri $currentUri -Method $Method -ErrorAction Stop
                }
                catch {
                    Write-Verbose "Suppressed probe error parse: $($_.Exception.Message)"
                    $statusCode = $null; $errorMessage = $_.Exception.Message; $detailReason = $null; $detailCode = $null; $rawBody = $null; $reqId=$null; $clientReqId=$null
                    try { $statusCode = $_.Exception.Response.StatusCode } catch { Write-Verbose "Suppressed status code extraction: $($_.Exception.Message)" }
                    try {
                        if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                            $reqId = $_.Exception.Response.Headers["request-id"]
                            if (-not $reqId) { $reqId = $_.Exception.Response.Headers["x-ms-request-id"] }
                            $clientReqId = $_.Exception.Response.Headers["client-request-id"]
                        }
                    } catch { Write-Verbose "Suppressed header extraction: $($_.Exception.Message)" }
                    # Try read response body (GraphServiceException sometimes exposes Content stream)
                    try {
                        if ($_.Exception.Response -and $_.Exception.Response.Content) {
                            try {
                                $stream = $_.Exception.Response.Content.ReadAsStream()
                                if ($stream.CanSeek) { $stream.Position = 0 }
                                $reader = New-Object System.IO.StreamReader($stream)
                                $rawBody = $reader.ReadToEnd()
                            } catch {
                                Write-Verbose "Suppressed body stream read: $($_.Exception.Message)"
                                try {
                                    $rawBody = $_.Exception.Response.Content.ReadAsStringAsync().Result
                                } catch { Write-Verbose "Suppressed ReadAsStringAsync: $($_.Exception.Message)" }
                            }
                        }
                    } catch { Write-Verbose "Suppressed body read: $($_.Exception.Message)" }
                    if (-not $rawBody) { try { $rawBody = $_.ErrorDetails.Message } catch { Write-Verbose "Suppressed ErrorDetails read: $($_.Exception.Message)" } }
                    if ($rawBody -and $script:EasyPIM_FullGraphError) {
                        $displayBody = $rawBody
                        if ($rawBody.Length -gt 4000) { $displayBody = $rawBody.Substring(0,4000) + '…' }
                        Write-Verbose ("Full Graph error body: {0}" -f $displayBody)
                    }
                    if ($rawBody) {
                        try {
                            $parsed = $rawBody | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($parsed.error) { $detailReason = $parsed.error.message; $detailCode = $parsed.error.code }
                        } catch { Write-Verbose "Suppressed error body JSON parse: $($_.Exception.Message)" }
                    }
                    # If we still don't have detail code/reason, probe with -SkipHttpErrorCheck to capture JSON
                    if (-not $detailCode -and -not $detailReason) {
                        try {
                            Write-Verbose "Probing error body with -SkipHttpErrorCheck for details"
                            $probe = Invoke-MgGraphRequest -Uri $currentUri -Method $Method -SkipHttpErrorCheck -ErrorAction SilentlyContinue
                            if ($probe) {
                                try { if ($probe.error) { $detailCode = $probe.error.code; $detailReason = $probe.error.message } } catch { Write-Verbose "Suppressed probe parse: $($_.Exception.Message)" }
                                if (-not $rawBody) { try { $rawBody = ($probe | ConvertTo-Json -Depth 10) } catch { $rawBody = ($probe | Out-String) } }
                            }
                        } catch { Write-Verbose "Suppressed SkipHttpErrorCheck probe: $($_.Exception.Message)" }
                    }
                    # Build a concise, human-readable summary
                    $summary = if ($detailCode -or $detailReason) { "$detailCode - $detailReason" } else { $errorMessage }
                    $composed = "Graph error ($statusCode): $summary"
                    # Add context fields tersely
                    $composed += " | method=$Method url=$currentUri"
                    if (-not ($detailCode -or $detailReason) -and $rawBody) { $snippet = ($rawBody -replace '\\s+',' '); if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) + '…' }; $composed += " | raw=$snippet" }
                    if ($reqId) { $composed += " | requestId=$reqId" }
                    if ($clientReqId) { $composed += " | clientRequestId=$clientReqId" }
                    if (Get-Command log -ErrorAction SilentlyContinue) { log $composed } else { Write-Verbose $composed }
                    throw $composed
                }

                # Check for error response (when using SkipHttpErrorCheck, errors come as response objects)
                if ($response.error) {
                    $errorCode = $response.error.code
                    $errorMessage = $response.error.message
                    if (Get-Command log -ErrorAction SilentlyContinue) {
                        log "Graph API error response: $errorCode - $errorMessage"
                    } else {
                        Write-Verbose "Graph API error response: $errorCode - $errorMessage"
                    }
                    throw "Graph API request failed: $errorCode - $errorMessage"
                }

                # Check if the response contains a value property (collection)
                if ($response.value) {
                    $allResults += $response.value

                    # Check if there are more pages
                    if ($response.'@odata.nextLink') {
                        $currentUri = $response.'@odata.nextLink'
                        Write-Verbose "Next page found: $currentUri"
                    }
                    else {
                        $hasMorePages = $false
                    }
                }
                else {
                    # Not a collection, just return the response
                    return $response
                }
            }

            # Return all collected results in the same format as the original Graph response
            # Preserve the original response structure but with all paginated results
            $originalResponse = $response  # Use the last response as template
            $originalResponse.value = $allResults
            # Remove pagination properties since we've collected all results
            if ($originalResponse.PSObject.Properties.Name -contains '@odata.nextLink') {
                $originalResponse.PSObject.Properties.Remove('@odata.nextLink')
            }
            return $originalResponse
        }
        else {
            # For non-GET methods or when pagination is disabled
            try {
                if ( $body -ne "") {
                    $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -Body $body -ContentType 'application/json' -ErrorAction Stop
                }
                else {
                    $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -ErrorAction Stop
                }

                # Check for error response
                if ($response.error) {
                    $errorCode = $response.error.code
                    $errorMessage = $response.error.message
                    if (Get-Command log -ErrorAction SilentlyContinue) {
                        log "Graph API error response: $errorCode - $errorMessage"
                    } else {
                        Write-Verbose "Graph API error response: $errorCode - $errorMessage"
                    }
                    throw "Graph API request failed: $errorCode - $errorMessage"
                }

                return $response
            }
            catch {
                $statusCode = $null; $errorMessage = $_.Exception.Message; $detailReason = $null; $detailCode = $null; $rawBody = $null; $reqId=$null; $clientReqId=$null
                try { $statusCode = $_.Exception.Response.StatusCode } catch { Write-Verbose "Suppressed status code extraction: $($_.Exception.Message)" }
                try {
                    if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                        $reqId = $_.Exception.Response.Headers["request-id"]
                        if (-not $reqId) { $reqId = $_.Exception.Response.Headers["x-ms-request-id"] }
                        $clientReqId = $_.Exception.Response.Headers["client-request-id"]
                    }
                } catch { Write-Verbose "Suppressed header extraction: $($_.Exception.Message)" }
                # Try read response body for detailed Graph error
                try {
                    if ($_.Exception.Response -and $_.Exception.Response.Content) {
                        try {
                            $stream = $_.Exception.Response.Content.ReadAsStream(); if ($stream.CanSeek) { $stream.Position = 0 }
                            $reader = New-Object System.IO.StreamReader($stream)
                            $rawBody = $reader.ReadToEnd()
                        } catch {
                            Write-Verbose "Suppressed body stream read: $($_.Exception.Message)"
                            try { $rawBody = $_.Exception.Response.Content.ReadAsStringAsync().Result } catch { Write-Verbose "Suppressed ReadAsStringAsync: $($_.Exception.Message)" }
                        }
                    }
                } catch { Write-Verbose "Suppressed body read: $($_.Exception.Message)" }
                if (-not $rawBody) { try { $rawBody = $_.ErrorDetails.Message } catch { Write-Verbose "Suppressed ErrorDetails read: $($_.Exception.Message)" } }
                if ($rawBody -and $script:EasyPIM_FullGraphError) {
                    $displayBody = $rawBody
                    if ($rawBody.Length -gt 4000) { $displayBody = $rawBody.Substring(0,4000) + '…' }
                    Write-Verbose ("Full Graph error body: {0}" -f $displayBody)
                }
                if ($rawBody) {
                    try {
                        $parsed = $rawBody | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($parsed.error) { $detailReason = $parsed.error.message; $detailCode = $parsed.error.code }
                    } catch { Write-Verbose "Suppressed error body JSON parse: $($_.Exception.Message)" }
                }
                # If details are still missing, probe with -SkipHttpErrorCheck for JSON error
                if (-not $detailCode -and -not $detailReason) {
                    try {
                        Write-Verbose "Probing $Method with -SkipHttpErrorCheck to capture error details"
                        if ($body -ne "") {
                            $probe = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -Body $body -ContentType 'application/json' -SkipHttpErrorCheck -ErrorAction SilentlyContinue
                        } else {
                            $probe = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -SkipHttpErrorCheck -ErrorAction SilentlyContinue
                        }
                        if ($probe) {
                            try { if ($probe.error) { $detailCode = $probe.error.code; $detailReason = $probe.error.message } } catch { Write-Verbose "Suppressed probe parse: $($_.Exception.Message)" }
                            if (-not $rawBody) { try { $rawBody = ($probe | ConvertTo-Json -Depth 10) } catch { $rawBody = ($probe | Out-String) } }
                        }
                    } catch { Write-Verbose "Suppressed SkipHttpErrorCheck probe: $($_.Exception.Message)" }
                }
                # Build a concise, human-readable summary
                $summary = if ($detailCode -or $detailReason) { "$detailCode - $detailReason" } else { $errorMessage }
                $composed = "Graph error ($statusCode): $summary"
                # Add context fields tersely
                $composed += " | method=$Method url=$uri"
                if (-not ($detailCode -or $detailReason) -and $rawBody) { $snippet = ($rawBody -replace '\\s+',' '); if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) + '…' }; $composed += " | raw=$snippet" }
                if ($reqId) { $composed += " | requestId=$reqId" }
                if ($clientReqId) { $composed += " | clientRequestId=$clientReqId" }
                if ($Method -ne 'GET' -and $body) { $b = ($body -replace '\\s+',' '); if ($b.Length -gt 160) { $b = $b.Substring(0,160) + '…' }; $composed += " | reqBody=$b" }
                if (Get-Command log -ErrorAction SilentlyContinue) { log $composed } else { Write-Verbose $composed }
                throw $composed
            }
        }
    }
    catch {
        if (Get-Command MyCatch -ErrorAction SilentlyContinue) { MyCatch $_ } else { throw $_ }
    }
}
