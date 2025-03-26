function Invoke-DeltaCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [array]$ConfigAssignments,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ApiInfo
    )
    
    Write-Output "Processing $ResourceType for delta cleanup..."
    
    $removeCounter = 0
    $skipCounter = 0
    
    foreach ($subscription in $ApiInfo.Subscriptions) {
        Write-Output "Checking subscription: $subscription"
        
        # Get role definitions for this subscription
        Write-Verbose "Getting role definitions for subscription $subscription"
        $roleMappings = Get-RoleMappings -SubscriptionId $subscription
        Write-Verbose "Found $($roleMappings.NameToId.Count) role definitions"
        
        # Get all assignments without filter - we'll filter in PowerShell instead
        Write-Verbose "Calling Azure REST API: $($ApiInfo.ApiEndpoint)"
        $restUri = "$($ApiInfo.ApiEndpoint)?api-version=2020-10-01&`$expand=principal,roleDefinition"
        Write-Verbose "REST URI: $restUri"
        $response = Invoke-AzRestMethod -Uri $restUri -Method GET
        
        Write-Verbose "API Response status code: $($response.StatusCode)"
        
        if ($response.StatusCode -eq 200) {
            $requests = ($response.Content | ConvertFrom-Json).value
            Write-Output "Found $($requests.Count) total schedule requests"
            
            # Filter for provisioned status in PowerShell
            Write-Verbose "Filtering for provisioned status..."
            $requests = $requests | Where-Object { $_.properties.status -eq "provisioned" }
            Write-Output "Found $($requests.Count) provisioned schedule requests"
            
            # Filter for our requests
            Write-Verbose "Filtering for requests created by this script..."
            $ourRequests = $requests | Where-Object { 
                $_.properties.justification -like "Created by Invoke-EasyPIMOrchestrator at*" 
            }
            
            Write-Output "Found $($ourRequests.Count) requests created by this script"
            
            foreach ($request in $ourRequests) {
                # Processing each request
                $principalId = $request.properties.principalId
                $principalName = $request.properties.principal.displayName
                $roleId = $request.properties.roleDefinitionId
                $displayRoleName = $request.properties.roleDefinition.displayName
                
                # Before actually removing:
                $actionDescription = "Remove $ResourceType assignment for $principalName with role $displayRoleName"
                
                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    # Perform the actual removal here
                    & $ApiInfo.RemoveCmd -tenantID $TenantId -scope $scope -principalId $principalId -roleName $roleName
                    $removeCounter++
                }
                else {
                    # This branch will be taken when -WhatIf is specified
                    $skipCounter++
                }
            }
        }
    }
    
    Write-Output "$ResourceType delta cleanup: $removeCounter removed, $skipCounter skipped"
}