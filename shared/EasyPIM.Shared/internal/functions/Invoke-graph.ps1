<#
Shared: invoke Microsof		if($endpointResolver){
			try { $graphBase = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -Verbose:$false } catch { Write-Verbose "invoke-graph: resolver failed, will fallback. Error: $($_.Exception.Message)" }Graph API wrapper with pagination and rich error handling.
Originally from EasyPIM core; moved to EasyPIM.Shared for cross-module use.
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
		# Resolve Graph base with robust fallback if resolver is unavailable in session
		$graphBase = $null
		$endpointResolver = Get-Command Get-PIMAzureEnvironmentEndpoint -ErrorAction SilentlyContinue
		if ($endpointResolver) {
			try { $graphBase = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' } catch { Write-Verbose "invoke-graph: resolver failed, will fallback. Error: $($_.Exception.Message)" }
		} else {
			Write-Verbose "invoke-graph: Get-PIMAzureEnvironmentEndpoint not found; using fallback mapping"
		}
		if (-not $graphBase) {
			# Fallback chain: env var -> AzContext mapping -> default Global
			if ($env:EASYPIM_GRAPH_ENDPOINT) { $graphBase = $env:EASYPIM_GRAPH_ENDPOINT.TrimEnd('/') }
			if (-not $graphBase) {
				try {
					$ctx = Get-AzContext -ErrorAction SilentlyContinue
					$envName = $ctx.Environment.Name
					switch ($envName) {
						'AzureUSGovernment' { $graphBase = 'https://graph.microsoft.us' }
						'AzureChinaCloud'   { $graphBase = 'https://microsoftgraph.chinacloudapi.cn' }
						'AzureGermanCloud'  { $graphBase = 'https://graph.microsoft.de' }
						Default             { $graphBase = 'https://graph.microsoft.com' }
					}
				} catch { $graphBase = 'https://graph.microsoft.com' }
			}
		}
		$graph = "$graphBase/$version/"

		[string]$uri = $graph + $endpoint
		if (-not [string]::IsNullOrEmpty($Filter)) {
			if ($uri -like "*`$filter=*") { $uri = $uri -replace "(\`$filter=[^&]*)", "`$1 and $Filter" }
			elseif ($uri.Contains("?")) { $uri += "&`$filter=$Filter" }
			else { $uri += "?`$filter=$Filter" }
		}

		Write-Verbose "uri = $uri"

		$tenantPref = $script:tenantID
		if(-not $tenantPref){ $gv = Get-Variable -Name tenantID -Scope Global -ErrorAction SilentlyContinue; if($gv){ $tenantPref = $gv.Value } }
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

		if ($Method -eq "GET" -and -not $NoPagination) {
			$allResults = @(); $currentUri = $uri; $hasMorePages = $true
			while ($hasMorePages) {
				Write-Verbose "Fetching data from: $currentUri"
				try { $response = Invoke-MgGraphRequest -Uri $currentUri -Method $Method -ErrorAction Stop }
				catch {
					Write-Verbose "Suppressed probe error parse: $($_.Exception.Message)"; $statusCode=$null; $errorMessage=$_.Exception.Message; $detailReason=$null; $detailCode=$null; $rawBody=$null; $reqId=$null; $clientReqId=$null
					try { $statusCode = $_.Exception.Response.StatusCode } catch {}
					try { if ($_.Exception.Response -and $_.Exception.Response.Headers) { $reqId = $_.Exception.Response.Headers["request-id"]; if (-not $reqId) { $reqId = $_.Exception.Response.Headers["x-ms-request-id"] }; $clientReqId = $_.Exception.Response.Headers["client-request-id"] } } catch {}
					try {
						if ($_.Exception.Response -and $_.Exception.Response.Content) {
							try { $stream = $_.Exception.Response.Content.ReadAsStream(); if ($stream.CanSeek) { $stream.Position = 0 }; $reader = New-Object System.IO.StreamReader($stream); $rawBody = $reader.ReadToEnd() }
							catch { try { $rawBody = $_.Exception.Response.Content.ReadAsStringAsync().Result } catch {} }
						}
					} catch {}
					if (-not $rawBody) { try { $rawBody = $_.ErrorDetails.Message } catch {} }
					if ($rawBody -and $script:EasyPIM_FullGraphError) { $displayBody=$rawBody; if ($rawBody.Length -gt 4000) { $displayBody = $rawBody.Substring(0,4000) + '…' }; Write-Verbose ("Full Graph error body: {0}" -f $displayBody) }
					if ($rawBody) { try { $parsed = $rawBody | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($parsed.error) { $detailReason = $parsed.error.message; $detailCode = $parsed.error.code } } catch {} }
					if (-not $detailCode -and -not $detailReason) {
						try { Write-Verbose "Probing error body with -SkipHttpErrorCheck for details"; $probe = Invoke-MgGraphRequest -Uri $currentUri -Method $Method -SkipHttpErrorCheck -ErrorAction SilentlyContinue; if ($probe) { try { if ($probe.error) { $detailCode = $probe.error.code; $detailReason = $probe.error.message } } catch {}; if (-not $rawBody) { try { $rawBody = ($probe | ConvertTo-Json -Depth 10) } catch { $rawBody = ($probe | Out-String) } } } } catch {}
					}
					$summary = if ($detailCode -or $detailReason) { "$detailCode - $detailReason" } else { $errorMessage }
					$composed = "Graph error ($statusCode): $summary"; $composed += " | method=$Method url=$currentUri"
					if (-not ($detailCode -or $detailReason) -and $rawBody) { $snippet = ($rawBody -replace '\s+',' '); if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) + '…' }; $composed += " | raw=$snippet" }
					if ($reqId) { $composed += " | requestId=$reqId" }
					if ($clientReqId) { $composed += " | clientRequestId=$clientReqId" }
					if (Get-Command log -ErrorAction SilentlyContinue) { log $composed } else { Write-Verbose $composed }
					throw $composed
				}

				if ($response.value) {
					$allResults += $response.value
					if ($response.'@odata.nextLink') { $currentUri = $response.'@odata.nextLink' } else { $hasMorePages = $false }
				} else { return $response }
			}
			$originalResponse = $response; $originalResponse.value = $allResults
			if ($originalResponse.PSObject.Properties.Name -contains '@odata.nextLink') { $originalResponse.PSObject.Properties.Remove('@odata.nextLink') }
			return $originalResponse
		}
		else {
			try {
				if ( $body -ne "") { $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -Body $body -ContentType 'application/json' -ErrorAction Stop }
				else { $response = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -ErrorAction Stop }
				if ($response.error) { $errorCode = $response.error.code; $errorMessage = $response.error.message; if (Get-Command log -ErrorAction SilentlyContinue) { log "Graph API error response: $errorCode - $errorMessage" } else { Write-Verbose "Graph API error response: $errorCode - $errorMessage" }; throw "Graph API request failed: $errorCode - $errorMessage" }
				return $response
			}
			catch {
				$statusCode=$null; $errorMessage=$_.Exception.Message; $detailReason=$null; $detailCode=$null; $rawBody=$null; $reqId=$null; $clientReqId=$null
				try { $statusCode = $_.Exception.Response.StatusCode } catch {}
				try { if ($_.Exception.Response -and $_.Exception.Response.Headers) { $reqId = $_.Exception.Response.Headers["request-id"]; if (-not $reqId) { $reqId = $_.Exception.Response.Headers["x-ms-request-id"] }; $clientReqId = $_.Exception.Response.Headers["client-request-id"] } } catch {}
				try { if ($_.Exception.Response -and $_.Exception.Response.Content) { try { $stream = $_.Exception.Response.Content.ReadAsStream(); if ($stream.CanSeek) { $stream.Position = 0 }; $reader = New-Object System.IO.StreamReader($stream); $rawBody = $reader.ReadToEnd() } catch { try { $rawBody = $_.Exception.Response.Content.ReadAsStringAsync().Result } catch {} } } } catch {}
				if (-not $rawBody) { try { $rawBody = $_.ErrorDetails.Message } catch {} }
				if ($rawBody -and $script:EasyPIM_FullGraphError) { $displayBody=$rawBody; if ($rawBody.Length -gt 4000) { $displayBody = $rawBody.Substring(0,4000) + '…' }; Write-Verbose ("Full Graph error body: {0}" -f $displayBody) }
				if ($rawBody) { try { $parsed = $rawBody | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($parsed.error) { $detailReason = $parsed.error.message; $detailCode = $parsed.error.code } } catch {} }
				if (-not $detailCode -and -not $detailReason) {
					try { Write-Verbose "Probing $Method with -SkipHttpErrorCheck to capture error details"; if ($body -ne "") { $probe = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -Body $body -ContentType 'application/json' -SkipHttpErrorCheck -ErrorAction SilentlyContinue } else { $probe = Invoke-MgGraphRequest -Uri "$uri" -Method $Method -SkipHttpErrorCheck -ErrorAction SilentlyContinue }; if ($probe) { try { if ($probe.error) { $detailCode = $probe.error.code; $detailReason = $probe.error.message } } catch {}; if (-not $rawBody) { try { $rawBody = ($probe | ConvertTo-Json -Depth 10) } catch { $rawBody = ($probe | Out-String) } } } } catch {}
				}
				$summary = if ($detailCode -or $detailReason) { "$detailCode - $detailReason" } else { $errorMessage }
				$composed = "Graph error ($statusCode): $summary"; $composed += " | method=$Method url=$uri"
				if (-not ($detailCode -or $detailReason) -and $rawBody) { $snippet = ($rawBody -replace '\s+',' '); if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) + '…' }; $composed += " | raw=$snippet" }
				if ($reqId) { $composed += " | requestId=$reqId" }
				if ($clientReqId) { $composed += " | clientRequestId=$clientReqId" }
				if ($Method -ne 'GET' -and $body) { $b = ($body -replace '\s+',' '); if ($b.Length -gt 160) { $b = $b.Substring(0,160) + '…' }; $composed += " | reqBody=$b" }
				if (Get-Command log -ErrorAction SilentlyContinue) { log $composed } else { Write-Verbose $composed }
				throw $composed
			}
		}
	}
	catch { if (Get-Command MyCatch -ErrorAction SilentlyContinue) { MyCatch $_ } else { throw $_ } }
}
