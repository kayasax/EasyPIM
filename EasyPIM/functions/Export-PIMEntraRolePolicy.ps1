<#
      .Synopsis
        Export the settings of the role $rolename to csv
      .Description
        Convert the policy rules to csv
      .Parameter tenantID
        EntraID tenant ID
      .Parameter rolename
        Array of the rolename to check
      .Parameter path
        path of the csv to genarate, if not specified default filename will be %appdata%\powershell\EasyPIM\Exports\EntraRoles_<datetime>.csv
      .Example
        PS> Export-PIMEntraRolePolicy -tenantID $tenantID  -rolename "Global Reader","Directory Writers" -path "c:\temp\role.csv"

        Export settings of "Global Reader" and "Directory Writers" roles to file c:\temp\role.csv
      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
    function Export-PIMEntraRolePolicy {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]]
        $rolename,
        
        [Parameter(Position = 2)]
        [System.String]
        $path
    )
    try {

        $script:tenantID = $tenantID
   
        Write-Verbose "Export-PIMEntraRolePolicy start with parameters: subscription => $subscriptionID, rolename=> $rolename, exportFilname => $path"
        
        
        # Array to contain the settings of each selected roles
        $exports = @()

        # run the flow for each role name.
        $rolename | ForEach-Object {
         
            #get curent config
            $config = get-EntraRoleconfig $_
            $exports += $config
        }
        $date = get-date -Format FileDateTime
        if (!($path)) { $path = "$script:_logPath\EXPORTS\EntraRoles_$date.csv" }
        log "exporting to $path"
        $exportPath = Split-Path $path -Parent
        #create export folder if no exist
        if ( !(test-path  $path) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        $exports | Select-Object * | ConvertTo-Csv | out-file $path
        log "Success! Script ended normaly"
    }
    catch {
        MyCatch $_
    }
}