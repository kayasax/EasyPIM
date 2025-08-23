<#
    .SYNOPSIS
    Visualize PIM activities.

    .DESCRIPTION
    Retrieves PIM-related audit events from Microsoft Graph and returns a summarized object array. Can optionally filter by user UPN. Also computes top categories and actors for HTML visualization.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID
    Returns recent PIM activity entries for the tenant with useful derived fields.

    .PARAMETER tenantID
    The Entra tenant ID to query.

    .PARAMETER upn
    Optional UPN filter to return only activities initiated by a specific user.

    .NOTES
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM

#>
function Show-PIMReport {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        # upn of the user
        $upn

    )
    try {
        $Script:tenantID = $tenantID

        $allresults = @()

        #$top = 100
        $endpoint = "auditlogs/directoryAudits?`$filter=loggedByService eq 'PIM'" #&`$top=$top"
        $result = invoke-graph -Endpoint $endpoint -Method "GET"
        $allresults += $result.value

        if ($result."@odata.nextLink") {
            do {
                $endpoint = $result."@odata.nextLink" -replace "https://graph.microsoft.com/v1.0/", ""
                $result = invoke-graph -Endpoint $endpoint -Method "GET"
                $allresults += $result.value
            }
            until(
                !($result."@odata.nextLink")
            )
        }

        #filter activities from the PIM service and completed activities
        $allresults = $allresults | Where-Object { $_ -and $_.initiatedby -and $_.initiatedby.values -and $_.initiatedby.values.userprincipalname } | Where-Object { $_.activityDisplayName -notmatch "completed" }

        # If no activities at all, return an empty array gracefully
        if (-not $PSBoundParameters.ContainsKey('upn')) {
            if (-not $allresults -or ($allresults | Measure-Object).Count -eq 0) {
                Write-Verbose "No PIM activities found for tenant $tenantID"
                return @()
            }
        }

        #check if upn parameter is set using psboundparameters
        if ($PSBoundParameters.ContainsKey('upn')) {
            Write-Verbose "Filtering activities for $upn"
            $allresults = $allresults | Where-Object {$_.initiatedby.values.userprincipalname -eq $upn}
            if ($allresults.count -eq 0) {
                Write-Warning "No activity found for $upn"
                return
            }
        }

        $Myoutput = @()

        $allresults | ForEach-Object {
            $props = @{}
            $props["activityDateTime"] = $_.activityDateTime
            $props["activityDisplayName"] = $_.activityDisplayName
            $props["category"] = $_.category
            $props["operationType"] = $_.operationType
            $props["result"] = $_.result
            $props["resultReason"] = $_.resultReason
            $props["initiatedBy"] = if ($_.initiatedBy -and $_.initiatedBy.values -and $_.initiatedBy.values.userprincipalname) { $_.initiatedBy.values.userprincipalname } else { $null }
            # role: first target resource display name if present
            $roleName = $null
            if ($_.targetResources -and (($_.targetResources | Measure-Object).Count -ge 1)) {
                $roleName = $_.targetResources[0].displayname
            }
            $props["role"] = $roleName
            if ($_.targetResources -and (($_.targetResources | Measure-Object).count -gt 2)) {
                if ($_.targetResources[2]["type"] -eq "User") {
                    $props["targetUser"] = $_.targetResources[2]["userprincipalname"]
                }
                elseif ($_.targetResources[2]["type"] -eq "Group") {
                    $props["targetGroup"] = $_.targetResources[2]["displayname"]
                }

                if (($_.targetResources | Measure-Object).count -gt 3) {
                    $props["targetResources"] = $_.targetResources[3]["displayname"]
                } else {
                    $props["targetResources"] = $roleName
                }
            }
            else {
                # fallback to first resource name if available
                if ($_.targetResources -and (($_.targetResources | Measure-Object).Count -ge 1)) {
                    $props["targetResources"] = $_.targetResources[0].displayname
                } else {
                    $props["targetResources"] = $null
                }
            }
            $Myoutput += New-Object PSObject -Property $props
        }
        $Myoutput

        #Data for the HTML report

        $props = @{}
        $stats_category = @{}
        $categories = $Myoutput | Group-Object -Property category
        $categories | ForEach-Object {
            $stats_category[$_.Name] = $_.Count
        }
        $props["category"] = $stats_category

        $stats_requestor = @{}
        $requestors = $Myoutput | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending | select-object -first 10
        $requestors | ForEach-Object {
            $stats_requestor[$_.Name] = $_.Count
        }
        $props["requestor"] = $stats_requestor

        $stats_result = @{}
        $results = $Myoutput | Group-Object -Property result
        $results | ForEach-Object {
            $stats_result[$_.Name] = $_.Count
        }
        $props["result"] = $stats_result

        $stats_activity = @{}
        $activities = $Myoutput | Group-Object -Property activityDisplayName
        $activities | ForEach-Object {
            if ($_.Name -notmatch "completed") {
                $stats_activity[$_.Name] = $_.Count
            }

        }
        $props["activity"] = $stats_activity

        $stats_group = @{}
        $targetgroup = $Myoutput | Where-Object { $_.category -match "group" } | Group-Object -Property targetresources | Sort-Object -Property Count -Descending | select-object -first 10
        $targetgroup | ForEach-Object {
            $stats_group[$_.Name] = $_.Count
        }
        $props["targetgroup"] = $stats_group

        $stats_resource = @{}
        $targetresource = $Myoutput | Where-Object { $_.category -match "resource" } | Group-Object -Property role | Sort-Object -Property Count -Descending | select-object -first 10
        $targetresource | ForEach-Object {
            $stats_resource[$_.Name] = $_.Count
        }
        $props["targetresource"] = $stats_resource

        $stats_role = @{}
        $targetrole = $Myoutput | Where-Object { $_.category -match "role" } | Group-Object -Property role | Sort-Object -Property Count -Descending | select-object -first 10
        $targetrole | ForEach-Object {
            $stats_role[$_.Name] = $_.Count
        }
        $props["targetrole"] = $stats_role
        $props["startdate"]=($Myoutput | Sort-Object -Property activityDateTime | Select-Object -First 1).activityDateTime
        $props["enddate"]=($Myoutput | Sort-Object -Property activityDateTime -Descending | Select-Object -First 1).activityDateTime

        #$props



        #building the dynamic part of the report
        $myscript = "

            <script>
            Chart.defaults.plugins.title.font.size = 18;
            Chart.defaults.plugins.title.color='#DDDDDD';
            Chart.defaults.plugins.legend.labels.color='#ffff99';
            Chart.defaults.scale.ticks.color = '#ffff99';

                const ctx = document.getElementById('myChart');
                new Chart(ctx, {
                    type: 'pie',
                    data: {
                        labels: ["
        $props.category.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                        datasets: [{
                            label: '# of activities',
                            data: ["
        $props.category.Keys | ForEach-Object {
            $myscript += "'" + $props.category[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Category',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            }

                        }
                    }
                });

                const ctx4 = document.getElementById('activities');
                new Chart(ctx4, {
                    type: 'pie',
                    data: {
                        labels: ["
        $props.activity.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma

        $myscript += "],

                        datasets: [{
                            label: '# of activities',
                            data: ["
        $props.activity.Keys | ForEach-Object {
            $myscript += "'" + $props.activity[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Activity type',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            }

                        }
                    }
                });

                const ctx2 = document.getElementById('result');
                new Chart(ctx2, {
                    type: 'pie',
                    data: {
                        labels: ['Success', 'Failure'],
                        datasets: [{
                            label: 'result',
                            data: ['"
        $myscript += $props.result['success']
        $myscript += "','"
        $myscript += $props.result['failure']
        $myscript += "'"


        $myscript += "],
                            backgroundColor: [
                                'rgb(0, 255, 0)',
                                'rgb(255, 0, 0)'
                            ],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Result',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },


                        }


                    }
                });


                const ctx3 = document.getElementById('requestor');
                new Chart(ctx3, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.requestor.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
        $props.requestor.Keys | ForEach-Object {
            $myscript += "'" + $props.requestor[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],

                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,


                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Requestors',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },


                        }


                    }
                });

                const ctx5 = document.getElementById('Groups');
                new Chart(ctx5, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.targetGroup.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
        $props.targetGroup.Keys | ForEach-Object {
            $myscript += "'" + $props.targetGroup[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],

                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,


                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Groups requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },


                        }


                    }
                });

                const ctx6 = document.getElementById('Resources');
                new Chart(ctx6, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.targetResource.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
        $props.targetresource.Keys | ForEach-Object {
            $myscript += "'" + $props.targetresource[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],

                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,


                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Azure role requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },


                        }


                    }
                });

                const ctx7 = document.getElementById('Roles');
                new Chart(ctx7, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.targetrole.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
        $props.targetrole.Keys | ForEach-Object {
            $myscript += "'" + $props.targetrole[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "") #remove the last comma
        $myscript += "],

                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,


                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,

                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Entra role requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },


                        }


                    }
                });

            </script>

        </body>

        </html>"

        #$myscript


        $html = @'

        <html>

<head>
    <title>EasyPIM: Activity summary</title>

</head>
<style>
    body {
        background-color: #2b2b2b;
        color: #f5f5f5;
    }

    #container {
        background-color: #3c3c3c;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        /* Optional: Adds some space between the divs */
    }

    .row {
        display: flex;
        padding: 10px;
        border-bottom: 1px solid #444;
    }

    .chart {
        flex: 1;
        /* Optional: Each div will take up an equal amount of space */
    }

    .description {
        flex: 1;
        /* Optional: Each div will take up an equal amount of space */
        vertical-align: middle;
        color:#a7a7a7;
    }

    code {
        font-family: Consolas, "Courier New", monospace;
        background-color: #203048;
        color: #f5f5f5;
        padding: 0.2em 0.4em;
        font-size: 85%;
        border-radius: 6px;
        line-height: 1.5;
    }

    #fixedDiv {
        background-color: #3c3c3c;
        color: #f5f5f5;
        position: fixed;
        top: 10;
        left: 980;
        width: 200px;
        /* Adjust as needed */
        height: 200px;

        /* Adjust as needed */
        padding: 10px;
        /* Adjust as needed */
        z-index: 1000;
        /* Ensure the div stays on top of other elements */
    }

    a {
        color: #1cd031;
    }
    H1,H2{
        text-align: center;
    }
    .header{
        border-bottom: #444 1px solid;
    }
    .footer{
        text-align: center;
        color: #a7a7a7;
    }
</style>


<body>
    <div id="fixedDiv">Navigation
        <ul>
            <li><a href="#myChart">Category</a></li>
            <li><a href="#result">Result</a></li>
            <li><a href="#activities">Activities</a></li>
            <li><a href="#requestor">Requestor</a></li>
            <li><a href="#Groups">Groups</a></li>
            <li><a href="#Resources">Azure Roles</a></li>
            <li><a href="#Roles">Entra Roles</a></li>
        </ul>
    </div>
    <div id="container" style="width: 950px">
    <div class="header">
        <h1>PIM activity summary</h1>
    <h2>from
'@

$html+= $props['startdate'].ToString() + " to " + $props['enddate'].ToString() + "</h2></div>"
$html += @'
        <div class="row">
            <div class="chart">
                <canvas id="myChart" width="900" height="200"></canvas>
            </div>
        </div>
        <div class="row">
            <div class="description">
                Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
                filter the activity for a specific category:<br>
                <pre><code>$r | where-object { $_.category -eq "GroupManagement" }</code></pre>
            </div>
        </div>

        <div class="row">
            <div class="chart">
                <canvas id="result" width="900" height="200"></canvas>
            </div>
        </div>
        <div class="row">
            <div class="description">
                Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
                consult the failed operations:<br>
                <code>$r | where-object {$_.result -eq "Failure"}</code>
            </div>
        </div>


    <div class="row">
        <div class="chart">
            <canvas id="activities" width="900" height="400"></canvas>
        </div>

    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.activityDisplayName -eq "Add member to role in PIM requested (timebound)"}</code>
        </div>
    </div>

    <div class="row">
        <div class="chart">
            <canvas id="requestor" width="900" height="500"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            filter the activity requested by User1:<br>
            <code>$r | where-object {$_.Initiatedby -match "user1"}</code>
        </div>
</div>
        <div class="row">
        <div class="chart">
            <canvas id="Groups" width="900" height="500"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            get the details for a group:<br>
            <code>$r | where-object {$_.category -match "group" -and $_.targetresources -eq "PIM_GuestAdmins"}</code>
        </div>
        </div>
        <div class="row">
        <div class="chart">
            <canvas id="Resources" width="900" height="500"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details for a specific Azure role:<br>
            <code>$r | where-object {$_.category -match "resource" -and $_.role -eq "Reader"}</code>
        </div>
        </div>

        <div class="row">
        <div class="chart">
            <canvas id="Roles" width="900" height="500"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details for a specific Enntra role:<br>
            <code>$r | where-object {$_.category -match "role" -and $_.role -eq "Global Administrator"}</code>
        </div>
        </div>
        <div class='footer'>
        <p>Generated with <a href='https://powershellgallery.com/packages/EasyPIM'>EasyPIM</a></p>
    </div>
    </div> <!-- container -->

    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

'@
        $html += $myscript
        $html | Out-File -FilePath "$env:temp\PIMReport.html" -Force
        invoke-item "$env:temp\PIMReport.html"

    }
    catch {
        MyCatch $_
    }
}
