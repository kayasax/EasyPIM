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
        if ( $logfile -eq $null ) { 
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
            if ( (get-childitem $logfile | select -expand length) -gt $Maxsize) {
                echo "$(Get-Date -Format yyyy-MM-dd HH:mm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : Log size exceed $MaxSize, creating a new file." >> $logfile 
                 
                # rename current logfile
                $LogFileName = $($($LogFile -split "\\")[-1])
                $basename = ls $LogFile | select -expand basename
                $dirname = ls $LogFile | select -expand directoryname
     
                Write-Verbose "Rename-Item $LogFile ""$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"""
                Rename-Item $LogFile "$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"
     
                # keep $Maxfile  logfiles and delete the older ones
                $filesToDelete = ls  "$dirname\$basename*.log" | sort LastWriteTime -desc | select -Skip $Maxfile 
                $filesToDelete | remove-item  -force
            }
        }
     
        echo "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : $msg" >> $logfile
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
}
