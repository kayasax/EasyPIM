<#
    .Synopsis
    Visualize PIM activities
      
    .Description
    Visualire PIM activities
    
    .Example
    PS> Get-PIMReport -tennantID $tenantID

    

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
    
#>
function Show-PIMReport {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID
    )
    try {
        $allresults = @()

        $top=100
        $endpoint="auditlogs/directoryAudits?`$filter=loggedByService eq 'PIM'&`$top=$top"
        $result = invoke-graph -Endpoint $endpoint -Method "GET"
        
        $allresults += $result.value

        if($result."@odata.nextLink"){
            do{
                $endpoint=$result."@odata.nextLink" -replace "https://graph.microsoft.com/v1.0/",""
                $result = invoke-graph -Endpoint $endpoint -Method "GET"
                $allresults += $result.value
            }
            until(
                !($result."@odata.nextLink")
            )
        }

        #filter activities from the PIM service
        $allresults = $allresults |Where-Object{$_.initiatedby.values.userprincipalname -ne $null}


        $props=@{}
        

        $stats_category = @{}
        $categories = $allresults | Group-Object -Property category
        $categories | ForEach-Object {
            $stats_category[$_.Name] = $_.Count
        }
        $props["category"]=$stats_category

        $stats_requestor = @{}
        $requestors = $allresults.initiatedBy.values | Group-Object -Property userprincipalName | Sort-Object -Property Count -Descending -top 10
        $requestors | ForEach-Object {
            $stats_requestor[$_.Name] = $_.Count
        }
        $props["requestor"] = $stats_requestor

        $stats_result=@{}
        $results = $allresults | Group-Object -Property result
        $results | ForEach-Object {
            $stats_result[$_.Name] = $_.Count
        }
        $props["result"] =$stats_result

        $stats_activity=@{}
        $activities = $allresults | Group-Object -Property activityDisplayName
        $activities | ForEach-Object {
            if ($_.Name -notmatch "completed"){
                $stats_activity[$_.Name] = $_.Count
            }
            
        }
        $props["activity"]=$stats_activity

        $props["allresults"]=$allresults

        $output=New-Object PSObject -Property $props
        $output

    }
    catch {
        MyCatch $_
    }
}