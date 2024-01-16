function send-teamsnotif {
    [CmdletBinding()] #make script react as cmdlet (-verbose etc..)
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $message,
        [string] $details,
        [string] $stacktrace = $null
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
                "activityTitle" = "Stacktrace"
                "activityText"  = "$stacktrace"
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
