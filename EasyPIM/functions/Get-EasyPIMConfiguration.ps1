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

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig"
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
                Import-Module Az.KeyVault -Force
            }

            # Get secret from Key Vault
            $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
            if (-not $secret) {
                throw "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
            }

            $jsonString = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText
        } else {
            Write-Host "Reading from file '$ConfigFilePath'" -ForegroundColor Gray

            if (-not (Test-Path $ConfigFilePath)) {
                throw "Configuration file not found: $ConfigFilePath"
            }

            $jsonString = Get-Content -Path $ConfigFilePath -Raw
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
