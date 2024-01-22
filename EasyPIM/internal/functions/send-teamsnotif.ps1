<#
      .Synopsis
       Send message to Teams channel
      .Description
       The app "inbound webhook" must be configured for that channed and the url set in scripts/variables.ps1
      .Parameter message
       message to display
      .Parameter details
       placeholder for more details
      .Parameter myStackTrace
       place holder for stack trace
      .Example
       PS> send-teamsnotif "Error occured" "The source file was not found"

       Send a notification to teams webhook url
     
      .Notes
#>function send-teamsnotif {
    [CmdletBinding()] #make script react as cmdlet (-verbose etc..)
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $message,
        [string] $details,
        [string] $myStackTrace = $null
    )

    $JSONBody = @{
        "@type"    = "MessageCard"
        "@context" = "<http://schema.org/extensions>"
        "title"    = "Alert for $description @ $env:computername  "
        "text"     = "An exception occured:"
        "sections" = @(
            @{
                "activityTitle" = "Message : $message"
            },
            @{
                "activityTitle" = "Details : $details"
            },
            @{
                "activityTitle" = " Script path "
                "activityText"  = "$_scriptFullName"
            },
            
            @{
                "activityTitle" = "myStackTrace"
                "activityText"  = "$myStackTrace"
            }
        )
    }

    $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100
        
    $parameters = @{
        "URI"         = $teamsWebhookURL
        "Method"      = 'POST'
        "Body"        = $TeamMessageBody
        "ContentType" = 'application/json'
    }
    $null = Invoke-RestMethod @parameters
}
