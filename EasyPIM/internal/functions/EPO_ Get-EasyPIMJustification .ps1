function Get-EasyPIMJustification {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [string]$CustomJustification,
        
        [Parameter()]
        [switch]$IncludeTimestamp
    )
    
    if (-not [string]::IsNullOrWhiteSpace($CustomJustification)) {
        return $CustomJustification
    }
    
    $justification = "Created by EasyPIM Orchestrator"
    
    if ($IncludeTimestamp) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $justification += " at $timestamp"
    }
    
    return $justification
}