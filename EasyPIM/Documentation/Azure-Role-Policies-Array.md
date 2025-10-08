Note on formats

EasyPIM accepts either AzureRoles.Policies (array) or AzureRolePolicies (legacy object). If both are present in the same config, the orchestrator will throw an error and exit. Ensure your builder outputs only one Azure format.

Management Group vs. Subscription scopes

- For Management Group targets, set Scope to /providers/Microsoft.Management/managementGroups/<mgName>. The orchestrator routes these via the Scope parameter set to the core cmdlet, ensuring managementGroups ARM paths are used.
- For Subscription targets, set Scope to /subscriptions/<subId>/... The orchestrator passes SubscriptionId and a normalized scope to the core cmdlet, ensuring subscriptions ARM paths are used.

#### Azure Role Policies (array format - Template and Inline examples)

Template example:
{
  "AzureRoles": {
    "Policies": [
      {
        "RoleName": "Reader",
        "Scope": "/subscriptions/subscription-id",
        "Template": "Standard",
        "PolicySource": "template",
        "ApprovalRequired": true
      }
    ]
  }
}

Inline example:
{
  "AzureRoles": {
    "Policies": [
      {
        "RoleName": "Reader",
        "Scope": "/subscriptions/xxxx",
        "PolicySource": "inline",
        "Policy": {
          "ActivationDuration": "PT2H",
          "MaximumEligibilityDuration": "P30D",
          "MaximumActiveAssignmentDuration": "P30D",
          "ActivationRequirement": [ "MultiFactorAuthentication", "Justification", "Ticketing" ],
          "ApprovalRequired": true,
          "AllowPermanentEligibility": false,
          "AllowPermanentActiveAssignment": false,
          "AuthenticationContext": {
            "Enabled": true,
            "Value": "c2"
          },
          "Approvers": [
            { "Id": "xxxxxxxxxxxxxxxxxxxx", "Name": "JohnDoe" }
          ]
        }
      }
    ]
  }
}
# Azure Role Policies - Array Format (Template and Inline)

This document describes the array-based configuration format for Azure Resource role policies. It is backward-compatible with the existing object/dictionary format and supports Template and Inline entries.

Example (Template):

{
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
      "ApprovalRequired": false
    }
  },
  "AzureRoles": {
    "Policies": [
      {
        "RoleName": "Reader",
        "Scope": "/subscriptions/subscription-id",
        "Template": "Standard",
        "PolicySource": "template",
        "ApprovalRequired": true
      }
    ]
  }
}

Example (Inline):

{
  "AzureRoles": {
    "Policies": [
      {
        "RoleName": "Reader",
        "Scope": "/subscriptions/xxxx",
        "PolicySource": "inline",
        "Policy": {
          "ActivationDuration": "PT2H",
          "MaximumEligibilityDuration": "P30D",
          "MaximumActiveAssignmentDuration": "P30D",
          "ActivationRequirement": [ "MultiFactorAuthentication", "Justification", "Ticketing" ],
          "ApprovalRequired": true,
          "AllowPermanentEligibility": false,
          "AllowPermanentActiveAssignment": false,
          "AuthenticationContext": {
            "Enabled": true,
            "Value": "c2"
          },
          "Approvers": [
            { "Id": "xxxxxxxxxxxxxxxxxxxx", "Name": "JohnDoe" }
          ]
        }
      }
    ]
  }
}

Notes:
- RoleName and Scope are required on each entry.
- For Template entries, set Template plus optional overrides on the entry which will merge during resolution.
- For Inline entries, set PolicySource to inline and provide Policy with the full settings payload.
- Orchestrator automatically selects the correct ARM path based on Scope (managementGroups for MG, subscriptions for subscription).
