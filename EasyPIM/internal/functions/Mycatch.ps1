<#
      .Synopsis
       wrapper for all caught exceptions
      .Description
       the exception will be parsed to get the details, it will be logged and eventualy sent to Teams if the notification is enabled
      .Parameter e
       The exception that was sent
      .EXAMPLE
        PS> MyCatch $e

        Will log the details of the exception

      .Link

      .Notes

#>
   function MyCatch {
  [CmdletBinding()] param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]$e
  )
  begin {
    Write-Verbose "MyCatch begin block initialized"
  }
  process {
    Write-Verbose "MyCatch processing one error record"
    $err = ($e.exception.message | Out-String).Trim()
    $details = $e.ErrorDetails
    $position = $e.InvocationInfo.positionMessage
    # If message already contains our enriched 'Graph API request failed:' pattern keep it; else append details
    if ($details -and -not ($err -match 'code=')) {
      try {
        $raw = $details.Message
        if ($raw) {
          $parsed = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
          if ($parsed.error) { $err += " | rawCode=$($parsed.error.code) rawReason=$($parsed.error.message)" }
        }
      } catch { Write-Verbose "Suppressed JSON parse in MyCatch: $($_.Exception.Message)" }
    }
    # Handle log function gracefully - it might not be available in all contexts
    if (Get-Command log -ErrorAction SilentlyContinue) {
      log "An exception occured: $err `nDetails: $details `nPosition: $position"
    } else {
      Write-Verbose "An exception occured: $err `nDetails: $details `nPosition: $position"
    }
    # Re-throw enriched error only once (avoid nesting inner=inner=...)
    if ($err -match 'Error, script did not terminate gracefuly') {
      throw $err
    } else {
      throw "Error, script did not terminate gracefuly | inner=$err"
    }
  }
  end {
    Write-Verbose "MyCatch end block completed"
  }
}
