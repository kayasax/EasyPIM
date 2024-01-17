<# 
      .Synopsis
       invoke ARM REST API 
      .Description
       
      .Parameter RestURI 
       
      .Parameter Method
       
      .Parameter Body
       
      .Example
        Copy-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -copyFrom role1
      .Link
     
      .Notes
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


        
        if ( (get-azcontext) -eq $null) { 
            Write-Verbose ">> Connecting to Azure with tenantID $tenantID"
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