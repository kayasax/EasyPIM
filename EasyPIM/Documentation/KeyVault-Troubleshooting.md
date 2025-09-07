# Azure Key Vault Troubleshooting Guide

## Overview
This guide covers common Azure Key Vault issues encountered when using EasyPIM configurations, particularly the API/Portal synchronization problems that can cause secret corruption.

## Common Issues

### 1. Key Vault Secret Corruption/Truncation

**Symptoms:**
- `Get-EasyPIMConfiguration` fails with "Unexpected end when reading JSON"
- Secret appears complete in Azure Portal but fails via PowerShell
- Secret content shows only `{` or partial JSON

**Root Cause:**
Azure Key Vault API and Portal can sometimes become desynchronized, causing:
- Different "current" versions between API and Portal
- Corrupted secret versions during upload/update operations
- Race conditions during concurrent secret modifications

**Automatic Recovery:**
EasyPIM v2.0.15+ includes automatic recovery mechanisms:

```powershell
# The function will automatically attempt recovery and show version used
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Verbose

# Example output:
# VERBOSE: Using secret version: dc53fbbd6d69445dbc4a5fd59efdef44
# VERBOSE: Successfully loaded configuration from Key Vault
```

**Manual Recovery Options:**

1. **Use Specific Version:**
```powershell
# Get version history
Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -IncludeVersions

# Use a specific working version
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Version "abc123def456"
```

2. **Diagnostic Analysis:**
```powershell
# Use internal diagnostic function (advanced)
& (Get-Module EasyPIM) { Test-EasyPIMKeyVaultSecret -KeyVaultName "MyVault" -SecretName "PIMConfig" }
```

3. **Re-upload Secret:**
```powershell
# Re-upload the configuration to create a new clean version
$configJson = Get-Content "config.json" -Raw
$secureString = ConvertTo-SecureString $configJson -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -SecretValue $secureString
```

### 2. Az.KeyVault Module Compatibility

**Symptoms:**
- PowerShell errors about missing SecretValueText property
- ConvertFrom-SecureString errors

**Solution:**
EasyPIM includes multi-method compatibility for different Az.KeyVault versions:
- SecretValueText (older versions)
- ConvertFrom-SecureString -AsPlainText (newer versions)
- Marshal method (fallback)

**Recommended Az.KeyVault Versions:**
- Az.KeyVault 4.9.0 or later
- Az.KeyVault 6.3.0+ for best compatibility

### 3. Access Permissions

**Required Permissions:**
- Key Vault Secrets User (minimum)
- Key Vault Secrets Officer (for writing)

**Common Permission Issues:**
```powershell
# Test access
Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig"

# Check your permissions
Get-AzRoleAssignment -Scope "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name}"
```

## Best Practices

### 1. Key Vault Configuration
- Use RBAC (Azure role-based access control) instead of access policies
- Enable soft delete and purge protection
- Set appropriate network access rules

### 2. Secret Management
- Validate JSON before uploading to Key Vault
- Use consistent encoding (UTF-8)
- Monitor secret versions for unexpected changes
- Implement backup strategies

### 3. Error Handling
```powershell
try {
    $config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig"
} catch {
    Write-Warning "Key Vault access failed: $($_.Exception.Message)"

    # Fallback to local file
    $config = Get-EasyPIMConfiguration -ConfigFilePath "backup-config.json"
}
```

### 4. Monitoring
- Set up Azure Monitor alerts for Key Vault access failures
- Log secret access patterns
- Monitor for unexpected version creation

## Troubleshooting Steps

### Step 1: Verify Secret Version Information
```powershell
# Check current secret version and get detailed information
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Verbose

# The verbose output will show which version was used:
# VERBOSE: Using secret version: dc53fbbd6d69445dbc4a5fd59efdef44

# Manually check current version
$currentSecret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig"
Write-Host "Current version: $($currentSecret.Version)"
Write-Host "Created: $($currentSecret.Created)"
Write-Host "Content length: $($currentSecret.SecretValue | ConvertFrom-SecureString -AsPlainText | Measure-Object -Character | Select-Object -ExpandProperty Characters)"
```

### Step 2: Verify Connectivity
```powershell
# Test Key Vault access
Get-AzKeyVault -VaultName "MyVault"

# Test authentication
Get-AzContext
```

### Step 2: Check Secret Status
```powershell
# Get current secret
$secret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig"
$content = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText

Write-Host "Version: $($secret.Version)"
Write-Host "Length: $($content.Length)"
Write-Host "Valid JSON: $($content.Trim().StartsWith('{') -and $content.Trim().EndsWith('}'))"
```

### Step 3: Analyze Version History
```powershell
# Get recent versions
Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -IncludeVersions |
    Sort-Object Created -Descending |
    Select-Object Version, Created, Updated -First 5
```

### Step 4: Test JSON Validity
```powershell
# Test JSON parsing
try {
    $config = $content | ConvertFrom-Json
    Write-Host "✅ Valid JSON"
} catch {
    Write-Host "❌ Invalid JSON: $($_.Exception.Message)"
}
```

## Recovery Procedures

### Automatic Recovery (Recommended)
Let EasyPIM handle recovery automatically:
```powershell
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Verbose
```

### Manual Recovery
1. **Identify Good Version:**
```powershell
# Use diagnostic function to find valid versions
& (Get-Module EasyPIM) { Test-EasyPIMKeyVaultSecret -KeyVaultName "MyVault" -SecretName "PIMConfig" }
```

2. **Use Specific Version:**
```powershell
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig" -Version "good-version-id"
```

3. **Promote Good Version:**
```powershell
# Get content from good version
$goodSecret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -Version "good-version-id"
$goodContent = $goodSecret.SecretValue | ConvertFrom-SecureString -AsPlainText

# Create new current version
$secureString = ConvertTo-SecureString $goodContent -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -SecretValue $secureString
```

## Prevention

### 1. Validation Before Upload
```powershell
# Always validate JSON before uploading
$configJson = Get-Content "config.json" -Raw
try {
    $configJson | ConvertFrom-Json | Out-Null
    Write-Host "✅ JSON is valid"
} catch {
    Write-Error "❌ Invalid JSON: $($_.Exception.Message)"
    return
}

# Upload to Key Vault
$secureString = ConvertTo-SecureString $configJson -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig" -SecretValue $secureString
```

### 2. Backup Strategy
```powershell
# Regular backups
$config = Get-EasyPIMConfiguration -KeyVaultName "MyVault" -SecretName "PIMConfig"
$config | ConvertTo-Json -Depth 10 | Out-File "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
```

### 3. Monitoring Script
```powershell
# Daily validation script
$secret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "PIMConfig"
$content = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText

if ($content.Length -lt 100) {
    Send-MailMessage -To "admin@company.com" -Subject "Key Vault Secret Corruption Alert" -Body "Secret appears corrupted"
}
```

## Related Links
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [EasyPIM Configuration Guide](./Configuration.md)
- [PowerShell Az.KeyVault Module](https://docs.microsoft.com/en-us/powershell/module/az.keyvault/)
