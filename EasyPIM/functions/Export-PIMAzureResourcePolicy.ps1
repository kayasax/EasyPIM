<#
      .Synopsis
        Export the settings of the role $rolename at the subscription scope where subscription = $subscriptionID to $exportFilename, if not set file will be saved in %appdata%\powershell\EasyPIM\exports\
      .Description
        Convert the policy rules to csv
      .Parameter tenantID
        EntraID tenant ID
      .Parameter subscriptionID
        subscription ID
      .Parameter rolename
        Array of the rolename to check
      .Parameter exportFilename
        Filename of the csv to genarate, if not specified default filename will be %appdata%\powershell\EasyPIM\Exports\<datetime>.csv
      .Example
        PS> Export-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster -filename "c:\temp\myrole.csv"

        Export settings of contributor and webmaster roles to file c:\temp\myrole.csv
      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
     function Export-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        $tenantID,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        $subscriptionID,
        [Parameter(Position = 2, Mandatory = $true)]
        [System.String[]]
        $rolename,
        [Parameter(Position = 3)]
        [System.String]
        $exportFilename
    )
    try {

        $script:tenantID = $tenantID      
   
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
        $exports | Select-Object * | ConvertTo-Csv | out-file $exportFilename
        log "Success! Script ended normaly"
    }
    catch {
        MyCatch $_
    }
}