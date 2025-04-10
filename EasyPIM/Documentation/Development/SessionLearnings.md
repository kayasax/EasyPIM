# EasyPIM Session Learnings

This document tracks key learnings, patterns, and notes from EasyPIM sessions for future reference.

## Session Notes - 2025-04-09

### Key Concepts

#### PIM Assignment Types
- **Eligible Assignments**: Require activation before permissions are granted
- **Active Assignments**: Immediate permissions without activation

#### Duration Formats
Durations in EasyPIM follow the ISO 8601 standard:
- \PT8H\: 8 hours
- \P1D\: 1 day
- \P2D\: 2 days
- \P1M\: 1 month
- \P90D\: 90 days

#### Assignment Properties
- **Permanent Assignment**: Set \\
Permanent\: true\ for assignments that don't expire
- **Time-bound Assignment**: Set \\Duration\: \P90D\\ for assignments with specific duration
- **Default Behavior**: If neither is specified, maximum allowed duration by policy will be used
- **Precedence**: If both \Permanent\ and \Duration\ are specified, \Permanent\ takes precedence

#### Multiple Principal Assignments
For assigning the same role to multiple principals with identical settings:
\\\json
\AzureRoles\: [
  {
    \PrincipalIds\: [
      \00000000-0000-0000-0000-000000000001\,
      \00000000-0000-0000-0000-000000000002\
    ],
    \Role\: \Reader\,
    \Scope\: \/subscriptions/12345678-1234-1234-1234-123456789012\,
    \Duration\: \P90D\
  }
]
\\\

### Azure Best Practices for PIM

1. **Least Privilege**: Assign the minimum necessary permissions
2. **Use Time-Bound Assignments**: Prefer time-bound over permanent assignments
3. **Protected Users**: Always maintain a list of protected users
4. **Regular Reviews**: Perform regular access reviews
5. **Activation Requirements**: Configure appropriate approval requirements for sensitive roles
6. **Monitoring**: Enable and review PIM audit logs regularly

### Common Usage Patterns

#### Pattern: Regular Access Review Automation
- Export current configuration
- Review and update as needed
- Apply updates using delta mode

#### Pattern: Environment Setup
- Prepare configuration JSON based on environment needs
- Store in KeyVault for secure access
- Apply using initial mode for first-time setup

### Notes for Future Sessions

- Add notes here as you learn new things in future sessions

## Code Standards and Practices

### Naming Conventions
- **Use Singular Nouns**: Always use singular nouns for function names (e.g., `Get-PIMRole` not `Get-PIMRoles`)
- **Verb-Noun Format**: All functions follow PowerShell's standard Verb-Noun format
- **Approved Verbs**: Use only PowerShell approved verbs (Get, Set, New, Remove, etc.)

### Code Organization
- **Check Existing Helpers**: Before creating new helper functions, thoroughly check for existing helpers in the internal/functions directory
- **Avoid Duplication**: Reuse existing helper functions instead of creating duplicates
- **Function Documentation**: All functions should include comment-based help

### GitHub Copilot Session Continuity
- GitHub Copilot does not automatically remember previous conversations across different sessions
- This SessionLearnings.md file serves as a knowledge repository to maintain continuity
- When starting new sessions, reference this document for context about:
  - Coding standards and practices
  - Architectural decisions
  - Naming conventions
  - Commonly used patterns

### EasyPIM Module Structure
- **Public Functions**: Located in the functions/ directory with individual .ps1 files
- **Internal Functions**: Located in internal/functions/ directory
- **Configuration**: Stored in config/ directory
- **Documentation**: Maintained in Documentation/ directory

