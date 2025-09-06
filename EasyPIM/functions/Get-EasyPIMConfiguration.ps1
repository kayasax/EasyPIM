#Requires -Version 5.1

# PSScriptAnalyzer suppressions for this orchestration configuration function
# Write-Host calls are intentional for user interaction and configuration display

function Get-EasyPIMConfiguration {
    <#
    .SYNOPSIS
        Loads EasyPIM configuration from a file or Azure Key Vault.

    .DESCRIPTION
        This function loads configuration data for EasyPIM operations from either a JSON configuration file
        or from Azure Key Vault. The configuration is returned as a hashtable to ensure compatibility
        with ContainsKey() method calls.

    .PARAMETER ConfigFilePath
        Path to a JSON configuration file.

    .PARAMETER KeyVaultName
        Name of the Azure Key Vault containing the configuration.

    .PARAMETER SecretName
        Name of the secret in Azure Key Vault containing the configuration.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -ConfigFilePath "config.json"
    Supports // and /* */ comments when Remove-JsonComments helper is available.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig"
    Requires Az.KeyVault module and read access to the specified secret.
    #>
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            Write-Host "Reading configuration from Key Vault '$KeyVaultName', secret '$SecretName'" -ForegroundColor Gray

            # Import Az.KeyVault module if not already loaded
            if (-not (Get-Module -Name Az.KeyVault)) {
                Write-Verbose "Importing Az.KeyVault module"
                Import-Module Az.KeyVault -Force
            }
            
            # Check Az.KeyVault version for debugging
            $azKeyVaultVersion = (Get-Module Az.KeyVault).Version
            Write-Verbose "Using Az.KeyVault version: $azKeyVaultVersion"

            # Get secret from Key Vault
            $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
            if (-not $secret) {
                throw "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
            }

            # Handle both old and new Az.KeyVault module versions with robust compatibility
            $jsonString = $null
            
            # Method 1: Try SecretValueText (older Az.KeyVault versions)
            if ($secret.SecretValueText) {
                $jsonString = $secret.SecretValueText
                Write-Verbose "Retrieved secret using SecretValueText (older Az.KeyVault)"
            }
            # Method 2: Try ConvertFrom-SecureString -AsPlainText (newer PowerShell versions)
            elseif ($secret.SecretValue) {
                try {
                    $jsonString = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText
                    Write-Verbose "Retrieved secret using ConvertFrom-SecureString -AsPlainText"
                    
                    # Validate the result is not empty
                    if ([string]::IsNullOrWhiteSpace($jsonString)) {
                        throw "ConvertFrom-SecureString returned empty result"
                    }
                } catch {
                    Write-Verbose "ConvertFrom-SecureString failed: $($_.Exception.Message), trying Marshal method"
                    # Method 3: Fallback to Marshal method for compatibility
                    try {
                        $jsonString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
                        )
                        Write-Verbose "Retrieved secret using Marshal method"
                    } catch {
                        throw "Failed to retrieve secret using Marshal method: $($_.Exception.Message)"
                    }
                }
            } else {
                throw "Unable to retrieve secret value from Key Vault response - no SecretValue or SecretValueText property found"
            }

            # Final validation
            if ([string]::IsNullOrWhiteSpace($jsonString)) {
                throw "Secret value is empty or null after retrieval"
            }
            
            Write-Verbose "Secret retrieved successfully, length: $($jsonString.Length) characters"
        } else {
            Write-Host "Reading from file '$ConfigFilePath'" -ForegroundColor Gray

            if (-not (Test-Path $ConfigFilePath)) {
                throw "Configuration file not found: $ConfigFilePath"
            }

            $jsonString = Get-Content -Path $ConfigFilePath -Raw
        }

        # Normalize: strip supported // and /* */ comments if helper exists
        if (Get-Command -Name Remove-JsonComments -ErrorAction SilentlyContinue) {
            $jsonString = $jsonString | Remove-JsonComments
        }

        # Convert JSON to PSCustomObject and return it directly
        # The newer orchestrator functions work with PSCustomObjects
        $result = $jsonString | ConvertFrom-Json

        Write-Verbose "Configuration loaded successfully"
        return $result

    } catch {
        Write-Error "Failed to load configuration: $($_.Exception.Message)"
        throw
    }
}
