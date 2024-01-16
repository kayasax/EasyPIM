function Import-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Entra ID TenantID
        $TenantID,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        # Subscription ID
        $SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [String]
        # import settings from this csv file
        $Path
    )
    
    $scope = "subscriptions/$subscriptionID"
    $ARMhost = "https://management.azure.com"
    $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    
    #load settings
    Write-Verbose "Importing settings from $path"
    Import-Settings $Path
    Log "Success, exiting."
}