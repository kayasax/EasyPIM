<# 
      .Synopsis
       Export the settings of the role $rolename at the subscription scope where subscription = $subscription to $exportFilename, if not set file will be saved in %appdata%\powershell\EasyPIM\exports\
      .Description
       Convert the policy rules to csv
      .Parameter subscriptionID 
       subscription ID
      .Parameter rolename
       Array of the rolename to check
      .Parameter exportFilename
       Filename of the csv
      .Example
        Export-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -filename "c:\temp\myrole.csv"
      .Link
     
      .Notes
     #>
     function Export-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        $subscriptionID,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]]
        $rolename,
        [Parameter(Position = 2)]
        [System.String]
        $exportFilename
    )
    try {

   
        Write-Verbose "Export-PIMAzureResourcePolicy start with parameters: subscription => $subscriptionID, rolename=> $rolename, exportFilname => $exportFilename"
        $scope = "subscriptions/$subscriptionID"
        # Array to contain the settings of each selected roles 
        $exports = @()

        # run the flow for each role name.
        $rolename | ForEach-Object {
         
            #get curent config
            $config = get-config $scope $_
            $exports += $config    
        } 
        $date = get-date -Format FileDateTime
        if (!($exportFilename)) { $exportFilename = "$script:_logPath\EXPORTS\$date.csv" }
        log "exporting to $exportFilename"
        $exportPath = Split-Path $exportFilename -Parent
        #create export folder if no exist
        if ( !(test-path  $exportFilename) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        $exports | select * | ConvertTo-Csv | out-file $exportFilename
        log "Success! Script ended normaly"
    }
    catch {
        MyCatch $_
    }
}