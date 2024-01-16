#***************************************
#* CONFIGURATION
#***************************************

# LOG TO FILE ( if enable by default it will create a LOGS subfolder in the script folder, and create a logfile with the name of the script )
$script:logToFile = $true

# TEAMS NOTIDICATION
# set to $true if you want to send fatal error on a Teams channel using Webhook see doc to setup
$script:TeamsNotif = $true
#The description will be used as the notification subject
$script:description = "EasyPIM module to manage Azure role setting" 

#***************************************
#* PRIVATE VARIABLES DON'T TOUCH !!
#***************************************

#from now every error will be treated as exception and terminate the script
$script:_scriptFullName = $MyInvocation.scriptName
$script:_scriptName = Split-Path -Leaf $_scriptFullName
$script:HostFQDN = $env:computername + "." + $env:USERDNSDOMAIN
# ERROR HANDLING
$ErrorActionPreference = "STOP" # make all errors terminating ones so they can be catched

# Where logs are written to
$script:_logPath = "$env:appdata\powershell\easyPIM"


# your Teams Inbound WebHook URL
$script:teamsWebhookURL = "https://microsoft.webhook.office.com/webhookb2/0b9bf9c2-fc4b-42b2-aa56-c58c805068af@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/40db225a69854e49b617eb3427bcded8/8dd39776-145b-4f26-8ac4-41c5415307c7"


# Log in first with Connect-AzAccount if not using Cloud Shell
Write-Verbose ">> Connecting to Azure with tenantID $tenantID"
if ( (get-azcontext) -eq $null) { Connect-AzAccount -Tenant $tenantID }

# Get access Token
Write-Verbose ">> Getting access token"
$script:token = Get-AzAccessToken
#Write-Verbose ">> token=$($token.Token)"

# setting the authentication headers for MSGraph calls
$script:authHeader = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $token.Token
}