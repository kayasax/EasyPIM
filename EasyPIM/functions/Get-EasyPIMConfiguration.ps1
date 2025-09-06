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

    .PARAMETER Version
        Optional specific version of the Key Vault secret to retrieve.
        Use this parameter if you encounter corrupted secrets due to Azure Key Vault API/Portal sync issues.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -ConfigFilePath "config.json"
    Supports // and /* */ comments when Remove-JsonComments helper is available.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig"
    Requires Az.KeyVault module and read access to the specified secret.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Version "abc123def456"
    Retrieves a specific version of the secret, useful for recovery from corrupted current versions.

    .EXAMPLE
        $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Verbose
    Uses verbose output to see automatic recovery attempts if the current version is corrupted.

    .NOTES
        Azure Key Vault Troubleshooting:
        - If you encounter truncated or corrupted secrets, this function will automatically attempt recovery
        - The function checks recent versions and attempts to use a valid one
        - Use the -Version parameter to manually specify a known good version
        - Portal and API can sometimes show different "current" versions due to sync delays
        - For comprehensive diagnostics, see: EasyPIM/Documentation/KeyVault-Troubleshooting.md
    #>
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,

        [Parameter(Mandatory = $false, ParameterSetName = 'KeyVault')]
        [string]$Version
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            if ($Version) {
                Write-Host "Reading configuration from Key Vault '$KeyVaultName', secret '$SecretName', version '$Version'" -ForegroundColor Gray
            } else {
                Write-Host "Reading configuration from Key Vault '$KeyVaultName', secret '$SecretName'" -ForegroundColor Gray
            }

            # Import Az.KeyVault module if not already loaded
            if (-not (Get-Module -Name Az.KeyVault)) {
                Write-Verbose "Importing Az.KeyVault module"
                Import-Module Az.KeyVault -Force
            }

            # Check Az.KeyVault version for debugging
            $azKeyVaultVersion = (Get-Module Az.KeyVault).Version
            Write-Verbose "Using Az.KeyVault version: $azKeyVaultVersion"

            # Get secret from Key Vault with validation and recovery
            if ($Version) {
                $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -Version $Version
                Write-Verbose "Using specific version: $Version"
            } else {
                $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
            }
            if (-not $secret) {
                throw "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
            }

            Write-Verbose "Retrieved secret version: $($secret.Version)"
            Write-Verbose "Secret created: $($secret.Created)"

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

            # Output secret version information for troubleshooting
            Write-Host "✅ Using Key Vault secret version: $($secret.Version) (created: $($secret.Created.ToString('MM/dd/yyyy HH:mm')))" -ForegroundColor Green

            # Enhanced validation for Azure Key Vault corruption issues
            # Check for common Key Vault corruption patterns
            if ($jsonString.Length -le 10 -and $jsonString.Trim() -in @('{', '}', '"{', '"}', '{{', '}}')) {
                Write-Warning "Detected potentially corrupted Key Vault secret (length: $($jsonString.Length), content: '$jsonString')"
                Write-Warning "This may be due to Azure Key Vault version synchronization issues between Portal and API"

                # Attempt recovery by checking recent versions
                Write-Verbose "Attempting to recover from Key Vault version history..."
                try {
                    $allVersions = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -IncludeVersions
                    $recentVersions = $allVersions | Sort-Object Created -Descending | Select-Object -First 5

                    foreach ($version in $recentVersions) {
                        if ($version.Version -eq $secret.Version) {
                            continue # Skip the current corrupted version
                        }

                        Write-Verbose "Trying version $($version.Version) from $($version.Created)..."
                        $testSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -Version $version.Version
                        $testContent = $null

                        # Use the same retrieval methods
                        if ($testSecret.SecretValueText) {
                            $testContent = $testSecret.SecretValueText
                        } elseif ($testSecret.SecretValue) {
                            try {
                                $testContent = $testSecret.SecretValue | ConvertFrom-SecureString -AsPlainText
                            } catch {
                                try {
                                    $testContent = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($testSecret.SecretValue)
                                    )
                                } catch {
                                    continue # Skip this version
                                }
                            }
                        }

                        # Check if this version has valid content
                        if ($testContent -and $testContent.Length -gt 50 -and $testContent.Trim().StartsWith('{') -and $testContent.Trim().EndsWith('}')) {
                            Write-Host "🔧 Recovered from Key Vault version $($version.Version) (created: $($version.Created))" -ForegroundColor Yellow
                            Write-Host "   Original version $($secret.Version) appears corrupted, using recovered content" -ForegroundColor Yellow
                            $jsonString = $testContent
                            break
                        }
                    }
                } catch {
                    Write-Verbose "Version recovery failed: $($_.Exception.Message)"
                }

                # If still corrupted after recovery attempt
                if ($jsonString.Length -le 10) {
                    $errorMsg = @"
Key Vault secret appears to be corrupted or truncated.
- Current version: $($secret.Version)
- Content length: $($jsonString.Length) characters
- Content: '$jsonString'

This is often caused by Azure Key Vault API/Portal synchronization issues.

Troubleshooting steps:
1. Check the Azure Portal to verify the secret content
2. Try specifying a specific version: Get-EasyPIMConfiguration -KeyVaultName '$KeyVaultName' -SecretName '$SecretName' -Version 'specific-version-id'
3. Re-upload the secret if corruption persists
4. Consider using a local configuration file as backup

For more information, see: https://docs.microsoft.com/en-us/azure/key-vault/general/about-keys-secrets-certificates
"@
                    throw $errorMsg
                }
            }
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
