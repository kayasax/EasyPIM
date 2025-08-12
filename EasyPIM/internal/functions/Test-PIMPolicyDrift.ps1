<# Internal placeholder retained only to avoid breaking historical references.
The public implementation lives in functions/Test-PIMPolicyDrift.ps1.
This internal stub is intentionally inert.
#>
function Test-PIMPolicyDrift {
    <#
    Internal stub only. Real implementation is in functions/Test-PIMPolicyDrift.ps1.
    Keeping this stub (no parameters) prevents legacy scripts that dot-source internal path
    from failing; they will get already-defined public function.
    #>
    if (Get-Command -Name Test-PIMPolicyDrift -ErrorAction SilentlyContinue | Where-Object { $_.ScriptBlock -ne $MyInvocation.MyCommand.ScriptBlock }) {
        return
    }
    throw 'Public implementation missing; ensure module loaded.'
}

## (Original implementation removed; see public folder.)

