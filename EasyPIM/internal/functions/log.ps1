
function log {
    [CmdletBinding()]
    param(
        [string]$msg,
        $logfile = $null,
        $logdir = $(join-path -path $script:_logPath -childpath "LOGS"), # Path to logfile
        [switch]$noEcho, # if set dont display output to screen, only to logfile
        $MaxSize = 3145728, # 3MB
        #$MaxSize = 1,
        $Maxfile = 3 # how many files to keep
    )

    #do nothing if logging is disabled
    if ($true -eq $script:logToFile ) {
     
        # When no logfile is specified we append .log to the scriptname 
        if ( $null -eq $logfile ) { 
            $logfile = "EasyPIM.log"
        }
       
        # Create folder if needed
        if ( !(test-path  $logdir) ) {
            $null = New-Item -ItemType Directory -Path $logdir  -Force
        }
         
        # Ensure logfile will be save in logdir
        if ( $logfile -notmatch [regex]::escape($logdir)) {
            $logfile = "$logdir\$logfile"
        }
         
        # Create file
        if ( !(Test-Path $logfile) ) {
            write-verbose "$logfile not found, creating it"
            $null = New-Item -ItemType file $logfile -Force  
        }
        else {
            # file exists, do size exceeds limit ?
            if ( (get-childitem $logfile | Select-Object -expand length) -gt $Maxsize) {
                write-host "$(Get-Date -Format yyyy-MM-dd HH:mm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : Log size exceed $MaxSize, creating a new file." >> $logfile 
                 
                # rename current logfile
                $LogFileName = $($($LogFile -split "\\")[-1])
                $basename = Get-ChildItem $LogFile | Select-Object -expand basename
                $dirname = Get-ChildItem $LogFile | Select-Object -expand directoryname
     
                Write-Verbose "Rename-Item $LogFile ""$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"""
                Rename-Item $LogFile "$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"
     
                # keep $Maxfile  logfiles and delete the older ones
                $filesToDelete = Get-ChildItem  "$dirname\$basename*.log" | Sort-Object LastWriteTime -desc | Select-Object -Skip $Maxfile 
                $filesToDelete | remove-item  -force
            }
        }
     
        Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : $msg" >> $logfile
    }# end logging to file

    # Display $msg if $noEcho is not set
    if ( $noEcho -eq $false) {
        #colour it up...
        if ( $msg -match "Erreur|error") {
            write-host $msg -ForegroundColor red
        }
        elseif ($msg -match "avertissement|attention|warning") {
            write-host $msg -ForegroundColor yellow
        }
        elseif ($msg -match "info|information") {
            write-host $msg -ForegroundColor cyan
        }    
        elseif ($msg -match "succès|succes|success|OK") {
            write-host $msg -ForegroundColor green
        }
        else {
            write-host $msg 
        }
    }

    <# 
      .Synopsis
       Log message to file and display it on screen with basic colour hilighting.
       The function include a log rotate feature.
      .Description
       Write $msg to screen and file with additional inforamtions : date and time, 
       name of the script from where the function was called, line number and user who ran the script.
       If logfile path isn't specified it will default to C:\UPF\LOGS\<scriptname.ps1.log>
       You can use $Maxsize and $MaxFile to specified the size and number of logfiles to keep (default is 3MB, and 3files)
       Use the switch $noEcho if you dont want the message be displayed on screen
      .Parameter msg 
       The message to log
      .Parameter logfile
       Name of the logfile to use (default = <scriptname>.ps1.log)
      .Parameter logdir
       Path to the logfile's directory (defaut = <scriptpath>\LOGS)
       .Parameter noEcho 
       Don't print message on screen
      .Parameter maxSize
       Maximum size (in bytes) before logfile is rotate (default is 3MB)
      .Parameter maxFile
       Number of logfile history to keep (default is 3)
      .EXAMPLE
        log "A message to display on screen and file"
      .Example
        log "this message will not appear on screen" -noEcho
      .Link
     
      .Notes
      	Changelog :
         * 27/08/2017 version initiale	
         * 21/09/2017 correction of rotating step
      	Todo : 
     #>
}
