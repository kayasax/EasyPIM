<#
      .Synopsis
       Update policy with new rules
      .Description
       Patch $policyID with the rules $rules
      .Parameter PolicyID
       policy ID
      .Parameter rules
        rules
      .Example
        PS> Update-Policy -policyID $id -rules $rules

        Update $policyID with rules $rules
      .Link

      .Notes
#>
function Update-EntraRolePolicy  {
    param(
        $policyID,
        $rules
    )
  Log "Updating Policy $policyID" -noEcho
  $endpoint = "policies/roleManagementPolicies/$policyID"

  # Note: ShouldProcess is handled by the caller (Set-EPOEntraRolePolicy)

  # Normalize input: allow array of JSON strings or a prebuilt JSON string
  if ($rules -is [System.Array]) {
    # Each element should be a JSON fragment for a rule; convert each to object
    $ruleObjects = @()
    foreach ($r in $rules) {
      $frag = [string]$r
      if (-not [string]::IsNullOrWhiteSpace($frag)) {
        # Sanitize: remove trailing commas before closing braces/brackets which cause JSON parse errors
        $sanitized = $frag -replace ',\s*([}\]])', '$1'
        try { $ruleObjects += ($sanitized | ConvertFrom-Json -ErrorAction Stop) }
        catch {
          Write-Verbose "Failed to parse rule fragment after sanitize. Fragment: $frag"
          Write-Verbose "Sanitized: $sanitized"
      # Fallback: if primaryApprovers array is present/malformed, coerce to empty array and retry
      if ($sanitized -match '"primaryApprovers"') {
    $coerced = [regex]::Replace($sanitized, '(?s)"primaryApprovers"\s*:\s*\[.*?\]', '"primaryApprovers": []')
            try {
              $ruleObjects += ($coerced | ConvertFrom-Json -ErrorAction Stop)
              Write-Verbose "Recovered malformed approval rule by emptying primaryApprovers."
              continue
            } catch {
              Write-Verbose "Fallback parse also failed. Coerced: $coerced"
            }
          }
                  # Last resort: do NOT drop rules; fail fast with a clear error so the issue can be fixed at the source
                  if ($sanitized -match 'Approval_EndUser_Assignment' -or $sanitized -match '#microsoft\.graph\.unifiedRoleManagementPolicyApprovalRule') {
                    $preview = ($sanitized -replace '\s+', ' ')
                    throw "Malformed approval rule fragment detected; refusing to drop. Fix Set-Approval JSON. Fragment preview: $preview"
                  }
          throw "Entra policy rules serialization failed: $($_.Exception.Message)"
        }
      }
    }
    if ($ruleObjects.Count -eq 0) { throw "No rules provided for Entra role policy update." }
    $rulesArray = $ruleObjects
  }
  else {
    $rulesText = if ($null -ne $rules) { [string]$rules } else { '' }
    $rulesText = $rulesText.Trim()
    if (-not $rulesText) { throw "No rules provided for Entra role policy update." }
    # If we were passed a JSON-encoded string (e.g., starts and ends with quotes and contains \" escapes), decode it first
    if ($rulesText.StartsWith('"') -and $rulesText.EndsWith('"')) {
      try {
        $decodedCandidate = $rulesText | ConvertFrom-Json -ErrorAction Stop
        if ($decodedCandidate -is [string]) { $rulesText = $decodedCandidate; Write-Verbose "Decoded JSON-encoded rules string" }
      } catch { Write-Verbose "Decoding JSON-encoded rules string failed: $($_.Exception.Message)" }
    }

  # Normalize legacy joined strings: collapse leading/trailing commas/newlines and split-join by newlines to avoid stray commas
    $rulesText = ($rulesText -replace "^,\s*|\s*,$", '').Trim()
    $parts = $rulesText -split "\r?\n" | Where-Object { $_ -and $_.Trim() }
    if ($parts.Count -gt 1 -and (-not $rulesText.TrimStart().StartsWith('['))) {
      $rulesText = ($parts -join ",`n")
    }
  # Fix common malformed comma patterns from legacy callers
  $rulesText = $rulesText -replace '(\{|\[)\s*,', '$1'      # remove comma immediately after { or [
  $rulesText = $rulesText -replace ',\s*,', ','              # collapse double commas
  $rulesText = $rulesText -replace ',\s*([}\]])', '$1'       # remove trailing comma before } or ]
    # First attempt: wrap in array and parse (use actual newline `n, not literal \n)
    $rulesArrayJson = if (-not $rulesText.StartsWith('[')) { "[`n$rulesText`n]" } else { $rulesText }
    # Sanitize trailing commas before closing braces/brackets
    $rulesArrayJson = $rulesArrayJson -replace ',\s*([}\]])', '$1'
    try {
      $rulesArray = $rulesArrayJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Write-Verbose "Rules JSON array parse failed. Will attempt fragment splitting. Raw (truncated): $([string]::Copy($rulesArrayJson).Substring(0, [Math]::Min(300, $rulesArrayJson.Length)))"
      # Fallback: split on '},{' boundaries and parse fragments individually
  # Split between objects even if legacy code inserted double commas
  $split = [regex]::Split($rulesText, '}\s*,+\s*{')
      $ruleObjects = @()
      for ($i = 0; $i -lt $split.Count; $i++) {
        $frag = $split[$i].Trim()
        if (-not $frag) { continue }
        if (-not $frag.StartsWith('{')) { $frag = '{' + $frag }
        if (-not $frag.EndsWith('}')) { $frag = $frag + '}' }
        # sanitize malformed commas inside fragment
        $sanitized = $frag
        $sanitized = $sanitized -replace '(\{|\[)\s*,', '$1'  # remove comma immediately after { or [
        $sanitized = $sanitized -replace ',\s*,', ','          # collapse double commas
        $sanitized = $sanitized -replace ',\s*([}\]])', '$1'   # remove trailing comma before } or ]
        try {
          $ruleObjects += ($sanitized | ConvertFrom-Json -ErrorAction Stop)
    } catch {
          # Approval rule recovery: empty malformed primaryApprovers and retry
          if ($sanitized -match '"primaryApprovers"') {
            $coerced = [regex]::Replace($sanitized, '(?s)"primaryApprovers"\s*:\s*\[.*?\]', '"primaryApprovers": []')
      try { $ruleObjects += ($coerced | ConvertFrom-Json -ErrorAction Stop); Write-Verbose "Recovered malformed approval rule by emptying primaryApprovers (fragment split)."; continue } catch { Write-Verbose "Approval rule recovery (fragment split) failed: $($_.Exception.Message)" }
          }
          $preview = ($sanitized -replace '\s+', ' ')
          throw "Entra policy rules serialization failed: $($_.Exception.Message). Fragment preview: $preview"
        }
      }
      if ($ruleObjects.Count -eq 0) { throw "Entra policy rules serialization failed: no fragments parsed." }
      $rulesArray = $ruleObjects
    }
  }

  $payloadObject = @{ rules = $rulesArray }
  $body = $payloadObject | ConvertTo-Json -Depth 10

  Write-Verbose "Patch endpoint : $endpoint"
  Write-Verbose ("PATCH body preview: {0}" -f ([Regex]::Replace($body, '\\s+', ' ').Substring(0, [Math]::Min(240, $body.Length))))
  # Extra diagnostics: log the approval rule block length if present
  try {
    $approvalBlock = [regex]::Match($body, '(?s)\{\s*"@odata.type"\s*:\s*"#microsoft\.graph\.unifiedRoleManagementPolicyApprovalRule".*?\}').Value
    if ($approvalBlock) { Write-Verbose ("[Policy][Entra] Approval rule JSON length: {0}" -f $approvalBlock.Length) }
  } catch { Write-Verbose "[Policy][Entra] Approval rule diagnostics skipped: $($_.Exception.Message)" }
  try {
    $response = invoke-graph -Endpoint $endpoint -Method "PATCH" -Body $body
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match 'InvalidPolicy') {
      Write-Host "[Diagnostics] Full PATCH body for InvalidPolicy:" -ForegroundColor Yellow
      Write-Host $body -ForegroundColor DarkYellow
      # Attempt to isolate offending rule(s) by patching individually
      try {
        Write-Host "[Diagnostics] Attempting per-rule isolation..." -ForegroundColor Yellow
        $i = 0
    foreach ($r in $rulesArray) {
          $i++
          $single = @{ rules = @($r) } | ConvertTo-Json -Depth 10
          try {
            Write-Verbose "[Diagnostics] Testing rule #$i id=$($r.id) type=$($r.'@odata.type')"
      $null = invoke-graph -Endpoint $endpoint -Method "PATCH" -Body $single -ErrorAction Stop
            Write-Host ("[Diagnostics] Rule #{0} (id={1}) -> OK" -f $i, $r.id) -ForegroundColor Green
          } catch {
            Write-Host ("[Diagnostics] Rule #{0} (id={1}) -> FAILED: {2}" -f $i, $r.id, $_.Exception.Message) -ForegroundColor Red
          }
        }
      } catch { Write-Verbose "[Diagnostics] Per-rule isolation failed: $($_.Exception.Message)" }
    }
    throw
  }
  return $response
}
