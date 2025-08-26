<#
      .Synopsis
       invoke ARM REST API
      .Description
       wrapper function to get an access token and set authentication header for each ARM API call
      .Parameter RestURI
       the URI
      .Parameter Method
       http method to use
      .Parameter Body
       an optional body
      .Example
        PS> invoke-ARM -restURI $restURI -method "GET"

        will send an GET query to $restURI and return the response
      .Link

      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function Invoke-ARM {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $restURI,

        [Parameter(Position = 1)]
        [System.String]
        $method,

        [Parameter(Position = 2)]
        [System.String]
    $body="",

    [Parameter(Position = 3)]
    [System.String]
    $SubscriptionId
    )

    try{
        <#$scope = "subscriptions/$script:subscriptionID"
        $ARMhost = "https://management.azure.com"
        $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"#>

        write-verbose "`n>> request body: $body"
        write-verbose "requested URI : $restURI ; method : $method"

        # Ensure the URI is absolute (starts with https://)
        if (-not $restURI.StartsWith("https://")) {
            # If it's not absolute, prepare to make it absolute
            $baseUrl = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -Verbose:$false

            # If the URI starts with a slash, don't add another one
            if ($restURI.StartsWith("/")) {
                $restURI = "$baseUrl$restURI"
            } else {
                $restURI = "$baseUrl/$restURI"
            }
            Write-Verbose "Converted to absolute URI: $restURI"
        }

        # Resolve SubscriptionId for context when needed (non-management group scope)
        if($restURI -notmatch "managementgroups"){
            $resolvedSubscriptionId = $null
            # 1) Try to extract from the URI
            $m = [regex]::Match($restURI, "/subscriptions/([0-9a-fA-F\-]{36})")
            if ($m.Success) { $resolvedSubscriptionId = $m.Groups[1].Value }

            # 2) Explicit parameter
            if (-not $resolvedSubscriptionId -and $PSBoundParameters.ContainsKey('SubscriptionId') -and -not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
                $resolvedSubscriptionId = $SubscriptionId
            }

            # 3) Script/global variable (may be set by the caller module)
            if (-not $resolvedSubscriptionId -and $script:subscriptionID) { $resolvedSubscriptionId = $script:subscriptionID }
            if (-not $resolvedSubscriptionId) {
                try {
                    $gv = Get-Variable -Name subscriptionID -Scope Global -ErrorAction SilentlyContinue
                    if ($gv -and $gv.Value) { $resolvedSubscriptionId = [string]$gv.Value }
                } catch {}
            }

            # 4) Current Az context
            if (-not $resolvedSubscriptionId) {
                try {
                    $ctx = Get-AzContext -ErrorAction SilentlyContinue
                    if ($ctx -and $ctx.Subscription -and $ctx.Subscription.Id) { $resolvedSubscriptionId = $ctx.Subscription.Id }
                } catch {}
            }

            if ($resolvedSubscriptionId) {
                if (-not $script:subscriptionID) { $script:subscriptionID = $resolvedSubscriptionId }
                Write-Verbose "Resolved SubscriptionId: $resolvedSubscriptionId"
            } else {
                Write-Verbose "No SubscriptionId resolved from URI/param/context; continuing without subscription-bound context."
            }

            # Ensure Az context is connected to the right tenant (and subscription if available)
            $needConnect = $false
            try {
                $azCtx = Get-AzContext -ErrorAction SilentlyContinue
                if (-not $azCtx) { $needConnect = $true }
                elseif ($script:tenantID -and ($azCtx.Tenant.Id -ne $script:tenantID)) { $needConnect = $true }
                elseif ($resolvedSubscriptionId -and $azCtx.Subscription.Id -ne $resolvedSubscriptionId) { $needConnect = $true }
            } catch { $needConnect = $true }

            if ($needConnect) {
                Write-Verbose ">> Connecting to Azure (tenant=$script:tenantID, subscription=$resolvedSubscriptionId)"
                if ($resolvedSubscriptionId) { Connect-AzAccount -Tenantid $script:tenantID -Subscription $resolvedSubscriptionId | Out-Null }
                elseif ($script:tenantID)   { Connect-AzAccount -Tenantid $script:tenantID | Out-Null }
                else                        { Connect-AzAccount | Out-Null }
            }
        }


        #replaced with invoke-azrestmethod
        <#
        # Get access Token
        Write-Verbose ">> Getting access token"
        # now this will return a securestring https://learn.microsoft.com/en-us/powershell/azure/upcoming-breaking-changes?view=azps-12.2.0#get-azaccesstoken
        $token = Get-AzAccessToken -AsSecureString

        # setting the authentication headers for MSGraph calls
        $authHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $($token.Token | ConvertFrom-SecureString -AsPlainText)
        }

        if($body -ne ""){
            $response = Invoke-RestMethod -Uri $restUri -Method $method -Headers $authHeader -Body $body -verbose:$false
        }
        else{
            $response = Invoke-RestMethod -Uri $restUri -Method $method -Headers $authHeader -verbose:$false
        }
            #>
        if ($body -ne ""){
            $response = Invoke-AzRestMethod -Method $method -Uri $restURI -Payload $body
        }
        else {
            $response = Invoke-AzRestMethod -Method $method -Uri $restURI
        }

        return $response.content | convertfrom-json

    }
    catch{
        MyCatch $_
    }
}