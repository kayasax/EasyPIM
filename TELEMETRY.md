# EasyPIM Telemetry and Privacy

## Overview

EasyPIM.Orchestrator can collect anonymous usage statistics to help improve the tool. This telemetry is **completely optional** and **disabled by default**. You must explicitly opt-in to enable it.

## What We Collect

When telemetry is enabled, we collect:

### Usage Metrics
- Execution success/failure rates
- Execution duration (performance insights)
- Feature usage patterns (WhatIf mode, protected roles override)
- Operation types (policy changes, assignments, cleanup)
- Configuration size categories (Small/Medium/Large tenants)

### System Information
- PowerShell version
- Operating system type (Windows 10/11, Linux, macOS)
- EasyPIM module version
- Session identifiers (for correlating events)

### Privacy-Protected Identifiers
- **Encrypted tenant ID**: Your Azure AD tenant ID is hashed using SHA256 with a salt before transmission
- **Session ID**: Randomly generated GUID for each PowerShell session

## What We DON'T Collect

❌ **Personal Information**: No user names, email addresses, or personal identifiers
❌ **Sensitive PIM Data**: No role assignments, policies, or configuration details
❌ **Clear-text Tenant IDs**: Tenant identification is always encrypted
❌ **IP Addresses**: PostHog may log IP addresses but we don't store or analyze them
❌ **Configuration Contents**: No JSON configuration data or secrets

## How It Works

1. **Opt-in Only**: First time you run EasyPIM.Orchestrator, you'll be prompted to enable telemetry
2. **Configuration Setting**: Your choice is saved as `"ALLOW_TELEMETRY": true/false` in your config file
3. **Non-blocking**: Telemetry failures never affect your PIM operations
4. **Privacy-First**: All data is anonymized before transmission

## Data Flow

```
Your Tenant ID → SHA256 Hash → PostHog → Analytics Dashboard
   (secret)      (anonymized)    (stored)     (insights)
```

## How to Control Telemetry

### Enable Telemetry
Set in your configuration file:
```json
{
  "TelemetrySettings": {
    "ALLOW_TELEMETRY": true
  }
}
```

### Disable Telemetry
Set in your configuration file:
```json
{
  "TelemetrySettings": {
    "ALLOW_TELEMETRY": false
  }
}
```

### Helper Function
```powershell
# Disable telemetry for a specific configuration
Disable-EasyPIMTelemetry -ConfigurationFile "path/to/config.json"
```

## Data Retention

- **Telemetry data**: Retained for 12 months for product improvement analysis
- **Purpose**: Understanding usage patterns, identifying bugs, improving performance
- **Access**: Only EasyPIM maintainers have access to aggregated, anonymized data

## Legal and Compliance

### GDPR Compliance
- **Lawful basis**: Legitimate interest (product improvement)
- **Data minimization**: Only essential metrics collected
- **Right to opt-out**: Easily disabled in configuration
- **No personal data**: All identifiers are encrypted/anonymized

### Security
- **Encryption in transit**: HTTPS transmission to PostHog
- **No secrets**: PostHog project key is public (safe to include in code)
- **Minimal data**: Only operational metrics, no sensitive content

## Questions or Concerns?

- **GitHub Issues**: [Report concerns](https://github.com/kayasax/EasyPIM/issues)
- **Email**: Contact maintainers through GitHub
- **Documentation**: This document is the authoritative source

## Technical Details

### Encryption Implementation
```powershell
# Tenant ID hashing implementation
$Salt = "EasyPIM-Privacy-Salt-2025-PostHog"
$StringToHash = "$TenantId-$Salt"
$HashedIdentifier = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [System.Text.Encoding]::UTF8.GetBytes($StringToHash)
)
```

### Example Telemetry Event
```json
{
  "distinct_id": "a1b2c3d4e5f6...",  // Encrypted tenant ID
  "event": "orchestrator_execution",
  "properties": {
    "module_version": "1.0.7",
    "execution_mode": "WhatIf",
    "protected_roles_override": false,
    "tenant_size_category": "Medium",
    "policy_count": 15,
    "assignment_count": 42,
    "execution_duration_seconds": 120.5,
    "errors_encountered": 0,
    "success": true,
    "powershell_version": "5.1.22621.3810",
    "os_version": "Windows_11",
    "timestamp": "2025-08-30T15:30:00Z",
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

Thank you for helping make EasyPIM better! 🚀
