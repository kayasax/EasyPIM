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
        $body=""
    )

    try{
        <#$scope = "subscriptions/$script:subscriptionID"
        $ARMhost = "https://management.azure.com"
        $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"#>

        write-verbose "`n>> request body: $body"
        write-verbose "request URI : $restURI"


        if ( $null -eq (get-azcontext) -or ( (get-azcontext).Tenant.Id -ne $script:tenantID ) ) {
            Write-Verbose ">> Connecting to Azure with tenantID $script:tenantID"
            Connect-AzAccount -Tenant $script:tenantID
        }
    
        # Get access Token
        Write-Verbose ">> Getting access token"
        $token = Get-AzAccessToken
                
        # setting the authentication headers for MSGraph calls
        $authHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $token.Token
        }

        $response = Invoke-RestMethod -Uri $restUri -Method $method -Headers $authHeader -Body $body -verbose:$false
        return $response

    }
    catch{
        MyCatch $_
    }


}