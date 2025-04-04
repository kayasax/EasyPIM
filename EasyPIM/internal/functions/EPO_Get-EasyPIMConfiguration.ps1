function Get-EasyPIMConfiguration {
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath
    )
    
    Write-SectionHeader "Retrieving Configuration"
    
    # Load configuration from appropriate source
    if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
        Write-Host "Reading from Key Vault '$KeyVaultName', Secret '$SecretName'" -ForegroundColor Cyan
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
        $jsonContent = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText | Remove-JsonComments
    }
    else {
        Write-Host "Reading from file '$ConfigFilePath'" -ForegroundColor Cyan
        $jsonContent = Get-Content -Path $ConfigFilePath -Raw | Remove-JsonComments
    }
    
    # Parse and return the configuration
    return $jsonContent | ConvertFrom-Json
}
