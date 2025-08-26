<#
      .Synopsis
       Define if approval is required to activate a role, and who are the approvers (CSV parsing wrapper)
      .Description
       Wrapper for Set-Approval that handles CSV-format approval settings
      .Parameter ApprovalRequired
       Do we need an approval to activate a role?
      .Parameter Approvers
        Who is the approver? (CSV format)
        .PARAMETER entrarole
        set to true if configuration is for an entra role
      .EXAMPLE
        PS> Set-ApprovalFromCSV -ApprovalRequired "TRUE" -Approvers "@{Id=abc-123;Name=John;Type=user}"

        define John as approver and require approval

      .Link

      .Notes

#>
function Set-ApprovalFromCSV  {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApprovalRequired,
        [Parameter(Mandatory=$false)]
        [string]$Approvers,
        [Parameter(Mandatory=$false)]
        [switch]$entraRole
    )

    Write-Verbose "Set-ApprovalFromCSV: ApprovalRequired=$ApprovalRequired, Approvers=$Approvers, entraRole=$entraRole"

    # Convert string approval required to boolean
    $approvalBool = $null
    if (-not [string]::IsNullOrWhiteSpace($ApprovalRequired)) {
        $approvalBool = ($ApprovalRequired.ToUpper() -eq 'TRUE' -or $ApprovalRequired -eq '1')
    }

    # Parse approvers from CSV format
    $approversList = $null
    if (-not [string]::IsNullOrWhiteSpace($Approvers)) {
        $approversList = ConvertTo-ApproverList -text $Approvers
    }

    # Call the main Set-Approval function
    if ($entraRole) {
        return Set-Approval -ApprovalRequired $approvalBool -Approvers $approversList -entraRole
    } else {
        return Set-Approval -ApprovalRequired $approvalBool -Approvers $approversList
    }
}

function ConvertTo-ApproverList {
    param([string]$text)
    $result = @()
    if ([string]::IsNullOrWhiteSpace($text)) { return $result }

    # Normalize by removing wrapping array parentheses that older logic added
    $t = $text.Trim()

    # Find all @{...} segments if present, otherwise treat the entire string as one segment
    $segments = @()
    $rx = [regex]'@\{([^}]*)\}'
    $rxMatches = $rx.Matches($t)
    if ($rxMatches.Count -gt 0) {
        foreach ($m in $rxMatches) { $segments += $m.Groups[1].Value }
    } else {
        $segments = @($t)
    }

    foreach ($seg in $segments) {
        $segTxt = ($seg -replace '^\s*\{', '' -replace '\}\s*$', '').Trim()
        # Extract fields by regex (support separators ':' or '=') and optional quotes
        $id = $null; $userType = $null; $name = $null; $description = $null

        $idMatch = [regex]::Match($segTxt, '(?i)\bid\b\s*[:=]\s*"?([0-9a-f\-]{5,})"?')
        if ($idMatch.Success) { $id = $idMatch.Groups[1].Value }

        $typeMatch = [regex]::Match($segTxt, '(?i)\buserType\b\s*[:=]\s*"?([A-Za-z]+)"?')
        if ($typeMatch.Success) { $userType = $typeMatch.Groups[1].Value }

        # Use a simpler regex pattern that avoids quote escaping issues
        $nameMatch = [regex]::Match($segTxt, '(?i)\bname\b\s*[:=]\s*"?([^;"]+)"?')
        if ($nameMatch.Success) { $name = $nameMatch.Groups[1].Value }

        $descMatch = [regex]::Match($segTxt, '(?i)\bdescription\b\s*[:=]\s*"?([^;"]+)"?')
        if ($descMatch.Success) { $description = $descMatch.Groups[1].Value }

        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $result += [pscustomobject]@{
                Id          = $id
                Name        = $name
                Type        = $userType
                Description = $description
            }
        }
    }
    return $result
}
