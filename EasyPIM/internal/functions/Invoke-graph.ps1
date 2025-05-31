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
        $graph = "https://graph.microsoft.com/$version/"

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

        if ( $null -eq (get-mgcontext) -or ( (get-mgcontext).TenantId -ne $script:tenantID ) ) {
            Write-Verbose ">> Connecting to Azure with tenantID $script:tenantID"
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

            Connect-MgGraph -Tenant $script:tenantID -Scopes $scopes -NoWelcome
        }

        # Handle pagination if needed (for GET requests only)
        if ($Method -eq "GET" -and -not $NoPagination) {
            $allResults = @()
            $currentUri = $uri
            $hasMorePages = $true

            while ($hasMorePages) {
                Write-Verbose "Fetching data from: $currentUri"

                try {
                    $response = Invoke-MgGraphRequest -Uri $currentUri -Method $Method
                }
                catch {
                    # Handle Graph API errors properly
                    if ($_.Exception.Response.StatusCode) {
                        $statusCode = $_.Exception.Response.StatusCode
                        $errorMessage = $_.Exception.Message
                        if (Get-Command log -ErrorAction SilentlyContinue) {
                            log "Graph API error: $statusCode - $errorMessage"
                        } else {
                            Write-Verbose "Graph API error: $statusCode - $errorMessage"
                        }
                        throw "Graph API request failed: $statusCode - $errorMessage"
                    }
                    else {
                        throw $_
                    }
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
                    $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -Body $body
                }
                else {
                    $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method
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
                # Handle Graph API errors properly
                if ($_.Exception.Response.StatusCode) {
                    $statusCode = $_.Exception.Response.StatusCode
                    $errorMessage = $_.Exception.Message
                    if (Get-Command log -ErrorAction SilentlyContinue) {
                        log "Graph API error: $statusCode - $errorMessage"
                    } else {
                        Write-Verbose "Graph API error: $statusCode - $errorMessage"
                    }
                    throw "Graph API request failed: $statusCode - $errorMessage"
                }
                else {
                    throw $_
                }
            }
        }
    }
    catch {
        MyCatch $_
    }
}
