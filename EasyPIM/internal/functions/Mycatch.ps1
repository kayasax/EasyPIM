function MyCatch($e){
    
    $err = $($e.exception.message | out-string) 
    $details =$e.errordetails # |fl -force
    $position = $e.InvocationInfo.positionMessage
    $Exception = $e.Exception

    
    if ($TeamsNotif) { send-teamsnotif "$err" "$details<BR/> TIPS: try to check the scope and the role name" "$position" }
    Log "An exception occured: $err `nDetails: $details `nPosition: $position"
    Log "Error, script did not terminate normaly"
    break
}