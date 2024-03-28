<#
      .Synopsis
       invoke Microsoft Graph API
      .Description
       wrapper function to get an access token and set authentication header for each ARM API call
      .Parameter Endpoint
       the Graph endpoint
      .Parameter Method
       http method to use
      .Parameter Body
       an optional body
      .Example
        PS> invoke-Graph -URI $URI -method "GET"

        will send an GET query to $URI and return the response
      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
#>
function invoke-graph {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Endpoint,
        [String]
        $Method = "GET",
        [String]
        $version = "v1.0",
        [String]
        $body

    )

    try {
        $graph = "https://graph.microsoft.com/$version/"
    
        $uri = $graph + $endpoint

        if ( $null -eq (get-mgcontext) -or ( (get-mgcontext).TenantId -ne $script:tenantID ) ) {
            Write-Verbose ">> Connecting to Azure with tenantID $script:tenantID"
            $scopes = @( 
                "RoleManagementPolicy.ReadWrite.Directory", 
                "RoleManagement.ReadWrite.Directory",
                "RoleManagementPolicy.ReadWrite.AzureADGroup", 
                "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
                "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
                "PrivilegedAccess.ReadWrite.AzureADGroup")
                
            Connect-MgGraph -Tenant $script:tenantID -Scopes $scopes 
        }
      
        if ( $body -ne "") {
            Invoke-MgGraphRequest -Uri $uri -Method $Method -Body $body
        }
        else {
            Invoke-MgGraphRequest -Uri $uri -Method $Method
        }
    }

    catch {
        MyCatch $_
    }


}