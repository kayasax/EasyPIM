if (-not $script:principalCache) { $script:principalCache = @{} }
if (-not $script:principalObjectCache) { $script:principalObjectCache = @{} }
# Record provenance of this helper at load time
if (-not $script:TestPrincipalExists_Source) { $script:TestPrincipalExists_Source = $PSCommandPath }

function Test-PrincipalExists {
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
	param ([string]$PrincipalId)

	$deepLog = $false
	if ($env:EASYPIM_VERBOSE_PRINCIPAL) { $deepLog = $true }
	Write-Verbose ("[PrincipalExists] ENTRY for {0} (src: {1})" -f $PrincipalId, $script:TestPrincipalExists_Source)

	if ($script:principalCache.ContainsKey($PrincipalId)) {
		if ($deepLog) { Write-Host ("[PrincipalExists] CACHE HIT {0} -> {1}" -f $PrincipalId, $script:principalCache[$PrincipalId]) -ForegroundColor DarkGray } else { Write-Verbose ("[PrincipalExists] CACHE HIT {0} -> {1}" -f $PrincipalId, $script:principalCache[$PrincipalId]) }
		return $script:principalCache[$PrincipalId]
	}

	if ($deepLog) { Write-Host "[PrincipalExists] PRE-TRY" -ForegroundColor DarkGray } else { Write-Verbose "[PrincipalExists] PRE-TRY" }
	try {
		if ($deepLog) { Write-Host "[PrincipalExists] IN-TRY" -ForegroundColor DarkGray } else { Write-Verbose "[PrincipalExists] IN-TRY" }
		# Resolve tenant for visibility only; Invoke-Graph handles connection/env
		$tenantPref = $script:tenantID
		if(-not $tenantPref){ $gv = Get-Variable -Name tenantID -Scope Global -ErrorAction SilentlyContinue; if($gv){ $tenantPref = $gv.Value } }
		if(-not $tenantPref -and $env:TENANTID){ $tenantPref = $env:TENANTID }
		if($tenantPref){ Write-Verbose "[PrincipalExists] Using tenant: $tenantPref" }

	# Confirm endpoint resolver presence
	$resolver = Get-Command Get-PIMAzureEnvironmentEndpoint -ErrorAction SilentlyContinue
	if(-not $resolver){ if ($deepLog) { Write-Host "[PrincipalExists] WARNING: Get-PIMAzureEnvironmentEndpoint not found in session" -ForegroundColor Yellow } else { Write-Verbose "[PrincipalExists] Resolver not found; will fallback" } }
	else { if ($deepLog) { Write-Host ("[PrincipalExists] Endpoint resolver from: {0} ({1})" -f $resolver.Source, $resolver.Path) -ForegroundColor DarkGray } else { Write-Verbose ("[PrincipalExists] Resolver: {0}" -f $resolver.Source) } }

		# First, try getByIds which returns 200 with empty list if not found
		$graphBase = $null
		if ($resolver) {
			try { $graphBase = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -Verbose:$false } catch { Write-Host "[PrincipalExists] Resolver call failed, will fallback to mapping" -ForegroundColor Yellow }
		}
		if (-not $graphBase) {
			# Fallback: map Az environment to Graph endpoint, or use env var or default Global
			$fallback = $null
			try {
				$az = Get-AzContext -ErrorAction SilentlyContinue
				if ($az -and $az.Environment -and $az.Environment.Name) {
					switch ($az.Environment.Name) {
						'AzureCloud'        { $fallback = 'https://graph.microsoft.com' }
						'AzureUSGovernment' { $fallback = 'https://graph.microsoft.us' }
						'AzureChinaCloud'   { $fallback = 'https://microsoftgraph.chinacloudapi.cn' }
						'AzureGermanCloud'  { $fallback = 'https://graph.microsoft.de' }
						default { $fallback = $null }
					}
				}
			} catch {}
			if (-not $fallback) { $envEp = [Environment]::GetEnvironmentVariable('EASYPIM_GRAPH_ENDPOINT'); if($envEp){ $fallback = $envEp.TrimEnd('/') } }
			if (-not $fallback) { $fallback = 'https://graph.microsoft.com' }
			$graphBase = $fallback
			if ($deepLog) { Write-Host ("[PrincipalExists] GRAPH BASE (fallback): {0}" -f $graphBase) -ForegroundColor DarkGray } else { Write-Verbose ("[PrincipalExists] GRAPH BASE (fallback): {0}" -f $graphBase) }
		} else {
			if ($deepLog) { Write-Host ("[PrincipalExists] GRAPH BASE: {0}" -f $graphBase) -ForegroundColor DarkGray } else { Write-Verbose ("[PrincipalExists] GRAPH BASE: {0}" -f $graphBase) }
		}
	$uriGetByIds = "$graphBase/v1.0/directoryObjects/getByIds"
		$payload = @{ ids = @($PrincipalId); types = @("user","group","servicePrincipal","device") } | ConvertTo-Json -Depth 5
	Write-Verbose "[PrincipalExists] Request: POST $uriGetByIds"
	if ($deepLog) { Write-Host "[PrincipalExists] POST $uriGetByIds" -ForegroundColor DarkGray }
	try { $gbiresp = Invoke-Graph -Endpoint "directoryObjects/getByIds" -Method POST -version v1.0 -body $payload -NoPagination }
	catch { Write-Host ("[PrincipalExists] getByIds error: {0}" -f $_.Exception.Message) -ForegroundColor Yellow; throw }
		if ($gbiresp -and $gbiresp.value) {
			$found = @($gbiresp.value).Count
			if ($found -gt 0) {
				$script:principalCache[$PrincipalId] = $true
				$script:principalObjectCache[$PrincipalId] = ($gbiresp.value | Select-Object -First 1)
				Write-Verbose "Principal $PrincipalId exists (via getByIds)"
				return $true
			}
		}

	# Fallback to direct GET
	$uriGet = "$graphBase/v1.0/directoryObjects/$PrincipalId"
	Write-Verbose "[PrincipalExists] Request: GET $uriGet"
	if ($deepLog) { Write-Host "[PrincipalExists] GET  $uriGet" -ForegroundColor DarkGray }
	try { $response = Invoke-Graph -Endpoint "directoryObjects/$PrincipalId" -Method GET -version v1.0 -NoPagination }
	catch { Write-Host ("[PrincipalExists] GET error: {0}" -f $_.Exception.Message) -ForegroundColor Yellow; throw }
		$script:principalCache[$PrincipalId] = $true
		$script:principalObjectCache[$PrincipalId] = $response
		Write-Verbose "Principal $PrincipalId exists"
		return $true
	}
	catch {
		$statusCode = $null
		try { $statusCode = $_.Exception.Response.StatusCode } catch { Write-Verbose "Suppressed status code extraction: $($_.Exception.Message)" }
		$msg = $_.Exception.Message
		if (-not $statusCode) {
			try {
				$m = [regex]::Match($msg, 'Graph error \(([^\)]+)\)');
				if($m.Success){
					$codeToken = $m.Groups[1].Value
					switch -Regex ($codeToken) {
						'^(404|NotFound|ResourceNotFound)$' { $statusCode = 404; break }
						'^(403|Forbidden)$' { $statusCode = 403; break }
						'^(401|Unauthorized)$' { $statusCode = 401; break }
						'^(400|BadRequest)$' { $statusCode = 400; break }
					}
				}
			} catch {}
		}
		if ($statusCode -eq 404) {
			Write-Verbose "Principal $PrincipalId does not exist (404)"
			$script:principalCache[$PrincipalId] = $false
			return $false
		}
		if ($statusCode -in 401,403) {
			Write-Host "[WARN] Graph auth/permission issue while checking principal $PrincipalId (HTTP $statusCode). Ensure you've consented to Directory.Read.All and are connected to the right tenant." -ForegroundColor Yellow
		}
		if ($statusCode -eq 400) {
			Write-Verbose "Principal $PrincipalId probe returned BadRequest (400) - treating as non-existent or invalid ID in this tenant."
		}
	$script:principalCache[$PrincipalId] = $false
	Write-Verbose "Principal $PrincipalId existence check error: $msg"
	if ($deepLog) { Write-Host ("[PrincipalExists] ERROR: {0}" -f $msg) -ForegroundColor Yellow } else { Write-Verbose ("[PrincipalExists] ERROR: {0}" -f $msg) }
		return $false
	}
}
