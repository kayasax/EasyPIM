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
     function MyCatch($e){
      write-verbose "MyCatch function called"
    $err = $($e.exception.message | out-string)
    $details =$e.errordetails# |fl -force
    $position = $e.InvocationInfo.positionMessage
    #$Exception = $e.Exception
    
    if ($TeamsNotif) { send-teamsnotif "$err" "$details<BR/> TIPS: try to check the scope and the role name" "$position" }
    Log "An exception occured: $err `nDetails: $details `nPosition: $position"
    throw "Error, script did not terminate gracefuly" #fix issue #40
}