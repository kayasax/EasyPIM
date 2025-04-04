#***************************************
#* CONFIGURATION
#***************************************
write-verbose "variables.ps1 called"
# LOG TO FILE ( if enable by default it will create a LOGS subfolder in the script folder, and create a logfile with the name of the script )
$script:logToFile = $false
# Where logs are written to
$script:_logPath = "$env:appdata\powershell\easyPIM"

# TEAMS NOTIDICATION
# set to $true if you want to send fatal error on a Teams channel using Webhook see doc to setup
$script:TeamsNotif = $false
#The description will be used as the notification subject
$script:description = "EasyPIM module to manage Azure role setting"
# your Teams Inbound WebHook URL
$script:teamsWebhookURL = "https://microsoft.webhook.office.com/webhookb2/xxxxxxx/IncomingWebhook/xxxxxxxxxxxxxx"

#***************************************
#* PRIVATE VARIABLES DON'T TOUCH !!
#***************************************

#from now every error will be treated as exception and terminate the script
$script:_scriptFullName = $MyInvocation.scriptName
$script:_scriptName = "EasyPIM" #Split-Path -Leaf $_scriptFullName
$script:HostFQDN = $env:computername + "." + $env:USERDNSDOMAIN
# ERROR HANDLING
$ErrorActionPreference = "STOP" # make all errors terminating ones so they can be catched


#checking new version of easyPIM
try {
    $currentVersion = (get-module  easypim -listavailable| Sort-Object version -desc |Select-Object -first 1).version.toString()
    Write-Verbose $currentVersion
    $latestVersion = (Find-Module -Name EasyPIM).Version
    write-verbose $latestVersion

    if ($currentVersion -lt $latestVersion) {
        Write-Host "🔥 FYI: A newer version of EasyPIM is available! Run the command below to update to the latest version."
        Write-Host "💥 Installed version: $currentVersion → Latest version: $latestVersion" -ForegroundColor DarkGray
        Write-Host "✨ Update-Module EasyPIM" -NoNewline -ForegroundColor Green
        Write-Host " → Install the latest version of EasyPIM." -ForegroundColor Yellow
        #return $true
    }
} catch { Write-Verbose -Message $_}
