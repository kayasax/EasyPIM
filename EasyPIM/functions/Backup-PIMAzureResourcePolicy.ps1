<#
    .Synopsis
    Export PIM settings of all roles at the subscription scope to a csv file.
    Use the exportFilename parameter to specify the csv file, if not specified default filename
    will be %appdata%\powershell\EasyPIM\Exports\backup_<date>.csv

    .Description
    Convert the policy rules to a csv file

    .Example
    PS> Export-PIMAzureResourcePolicy -tennantID $tenantID -subscriptionID $subscriptionID -filename "c:\temp\myrole.csv"

    Export settings of all roles to file c:\temp\myrole.csv

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM

#>
function Backup-PIMAzureResourcePolicy {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(ParameterSetName = 'Default',Position = 1, Mandatory = $true)]
        [System.String]
        # subscription id
        $subscriptionID,

        [Parameter(ParameterSetName = 'Scope',Position = 1, Mandatory = $true)]
        [System.String]
        # scope
        $scope,

        [Parameter(Position = 2)]
        [System.String]
        # Filename of the csv to generate (legacy, use -path for consistency)
        $exportFilename,

        [Parameter(Position = 3)]
        [System.String]
        # Preferred: Path to the csv to generate (for consistency with other backup functions)
        $path
    )
    try {
        $script:tenantID = $tenantID
        $exports = @()
        if (!($PSBoundParameters.Keys.Contains('scope'))) {
            $scope = "subscriptions/$subscriptionID"
        }

        $policies = Get-AllPolicies $scope

        $policies | ForEach-Object {
            log "exporting $_ role settings"
            #write-verbose  $_
            try {
                $config = get-config $scope $_.Trim()
                if ($null -ne $config) {
                    $exports += $config
                }
            }
            catch {
                # Check if this is a 404 error (role has PIM policy at child scope like resource group)
                $is404 = $false
                if ($_.Exception.Response.StatusCode -eq 'NotFound' -or $_.Exception.Response.StatusCode.value__ -eq 404) {
                    $is404 = $true
                }
                elseif ($_.Exception.Message -match '404|Not Found') {
                    $is404 = $true
                }
                
                if ($is404) {
                    Write-Warning "⚠️ Skipping role '$_' - PIM policy not found at scope '$scope'. Role may be configured at child scope level (e.g., resource group)."
                }
                else {
                    # For non-404 errors, re-throw to maintain existing error handling
                    throw
                }
            }
        }
        $date = get-date -Format FileDateTime
        # Prefer -path if provided, else fallback to -exportFilename, else default
        $finalPath = $null
        if ($path) {
            $finalPath = $path
        } elseif ($exportFilename) {
            $finalPath = $exportFilename
        } else {
            $finalPath = "$script:_LogPath\EXPORTS\BACKUP_$date.csv"
        }
        log "exporting to $finalPath"
        $exportPath = Split-Path $finalPath -Parent
        #create export folder if no exist
        if ( !(test-path  $exportPath) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }

        $exports | Select-Object * | ConvertTo-Csv | out-file $finalPath
    }
    catch {
        MyCatch $_
    }
}
