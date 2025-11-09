<#
    .SYNOPSIS
    Visualize PIM activities in multiple formats (HTML, CSV, JSON).

    .DESCRIPTION
    Retrieves PIM-related audit events from Microsoft Graph and returns a summarized object array. Can optionally filter by user UPN.
    Supports multiple output formats:
    - HTML: Interactive report with charts (default, opens in browser unless -NoAutoOpen specified)
    - CSV: Automation-friendly format for Azure runbooks and scripts
    - JSON: Structured data for APIs and programmatic use

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID
    Generates interactive HTML report with charts and opens in browser (default behavior).

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -Format CSV
    Exports PIM activity data to CSV file in temp directory for Azure Automation runbooks. Returns object with Data and FilePath properties.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -Format CSV -Path "C:\Reports\PIM-Activity.csv"
    Exports PIM activity data to specific CSV file path. Creates directory if it doesn't exist.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -Format JSON -Path "\\server\share\reports\PIM-$(Get-Date -Format 'yyyyMMdd')"
    Exports to network share with custom filename (extension automatically added).

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -Format JSON
    Exports PIM activity data to JSON file in temp directory for API integration. Returns object with Data and FilePath properties.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -upn "user@domain.com" -Format CSV -Path "./user-activity.csv"
    Filters PIM activities for specific user and exports to relative path in current directory.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -NoAutoOpen
    Generates HTML report and saves to temp directory without opening it. Returns object with Data and FilePath properties.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -NoAutoOpen -Path "C:\Reports\PIM-Report.html"
    Saves HTML report to specific path without opening it. Useful for server environments or batch processing.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -NoCodeSnippets
    Generates HTML report without PowerShell code snippets for management presentations.

    .EXAMPLE
    Show-PIMReport -tenantID $tenantID -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)
    Generates report for activities in the last 30 days.

    .PARAMETER tenantID
    The Entra tenant ID to query.

    .PARAMETER upn
    Optional UPN filter to return only activities initiated by a specific user.

    .PARAMETER Format
    Output format: 'HTML' for interactive reports (default), 'CSV' for automation scenarios, 'JSON' for programmatic use.

    .PARAMETER Path
    Custom file path for CSV/JSON export. If not specified, uses temp directory with timestamp.
    Directory will be created if it doesn't exist. File extension (.csv/.json) is added automatically if not provided.

    .PARAMETER NoAutoOpen
    When specified with HTML format, saves the HTML file without automatically opening it in the default browser.
    Useful for server environments, batch processing, or when you want to save the HTML file for later viewing.

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
    $upn,
    [Parameter()]
    [ValidateSet('HTML', 'CSV', 'JSON')]
    [String]
    # Output format: HTML (interactive report), CSV (automation-friendly), JSON (programmatic use)
    $Format = 'HTML',
    [Parameter()]
    [String]
    # Custom file path for CSV/JSON export. If not specified, uses temp directory with timestamp
    $Path,
    [Parameter()]
    [Switch]
    # When specified with HTML format, saves the HTML file without automatically opening it
    $NoAutoOpen,
    [Parameter()]
    [Switch]
    # Hide PowerShell code examples in HTML report for management presentations
    $NoCodeSnippets,
    [Parameter()]
    [DateTime]
    # Start date for filtering PIM activities
    $StartDate,
    [Parameter()]
    [DateTime]
    # End date for filtering PIM activities
    $EndDate
    )
    try {
        $Script:tenantID = $tenantID

        $allresults = @()

        # Build filter with date range if specified
        $filter = "loggedByService eq 'PIM'"
        if ($StartDate -or $EndDate) {
            if ($StartDate) {
                $startDateStr = $StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                $filter += " and activityDateTime ge $startDateStr"
            }
            if ($EndDate) {
                $endDateStr = $EndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                $filter += " and activityDateTime le $endDateStr"
            }
        }

        $endpoint = "auditlogs/directoryAudits?`$filter=$filter"
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

        # Handle different output formats
        switch ($Format) {
            'CSV' {
                # Generate CSV file for Azure Automation and non-interactive scenarios
                if ($Path) {
                    $csvPath = $Path
                    # Ensure .csv extension if not provided
                    if (-not $csvPath.EndsWith('.csv', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $csvPath += '.csv'
                    }
                } else {
                    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                    $csvPath = "$env:temp\PIMReport-$timestamp.csv"
                }

                # Ensure directory exists
                $directory = Split-Path -Path $csvPath -Parent
                if ($directory -and -not (Test-Path -Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }

                $Myoutput | Export-Csv -Path $csvPath -NoTypeInformation -Force
                Write-Verbose "CSV report generated: $csvPath"
                return @{
                    Data = $Myoutput
                    FilePath = $csvPath
                    Format = 'CSV'
                }
            }
            'JSON' {
                # Generate JSON file for programmatic use and APIs
                if ($Path) {
                    $jsonPath = $Path
                    # Ensure .json extension if not provided
                    if (-not $jsonPath.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $jsonPath += '.json'
                    }
                } else {
                    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                    $jsonPath = "$env:temp\PIMReport-$timestamp.json"
                }

                # Ensure directory exists
                $directory = Split-Path -Path $jsonPath -Parent
                if ($directory -and -not (Test-Path -Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }

                $Myoutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Force
                Write-Verbose "JSON report generated: $jsonPath"
                return @{
                    Data = $Myoutput
                    FilePath = $jsonPath
                    Format = 'JSON'
                }
            }
            'HTML' {
                # Continue with existing HTML generation logic
                # For HTML format, Path parameter can be used to specify custom location
                # Return the data array for backward compatibility only when auto-opening
                if (-not $NoAutoOpen) {
                    $Myoutput
                }
            }
        }

        #Data for the HTML report

        # Calculate summary statistics (used for old HTML generation path)
        $startDate = ($Myoutput | Sort-Object -Property activityDateTime | Select-Object -First 1).activityDateTime
        $endDate = ($Myoutput | Sort-Object -Property activityDateTime -Descending | Select-Object -First 1).activityDateTime

        $props = @{}
        $stats_category = [ordered]@{}
        $categories = $Myoutput | Group-Object -Property category
        $categories | ForEach-Object {
            $stats_category[$_.Name] = $_.Count
        }
        $props["category"] = $stats_category

        $stats_requestor = [ordered]@{}
        $requestors = $Myoutput | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending | select-object -first 10
        $requestors | ForEach-Object {
            $stats_requestor[$_.Name] = $_.Count
        }
        $props["requestor"] = $stats_requestor

        $stats_result = [ordered]@{}
        $results = $Myoutput | Group-Object -Property result
        $results | ForEach-Object {
            $stats_result[$_.Name] = $_.Count
        }
        $props["result"] = $stats_result

        $stats_activity = [ordered]@{}
        $activities = $Myoutput | Group-Object -Property activityDisplayName
        $activities | ForEach-Object {
            if ($_.Name -notmatch "completed") {
                $stats_activity[$_.Name] = $_.Count
            }

        }
        $props["activity"] = $stats_activity

        $stats_group = [ordered]@{}
        $targetgroup = $Myoutput | Where-Object { $_.category -match "group" } | Group-Object -Property targetresources | Sort-Object -Property Count -Descending | select-object -first 10
        $targetgroup | ForEach-Object {
            $stats_group[$_.Name] = $_.Count
        }
        $props["targetgroup"] = $stats_group

        $stats_resource = [ordered]@{}
        $targetresource = $Myoutput | Where-Object { $_.category -match "resource" } | Group-Object -Property role | Sort-Object -Property Count -Descending | select-object -first 10
        $targetresource | ForEach-Object {
            $stats_resource[$_.Name] = $_.Count
        }
        $props["targetresource"] = $stats_resource

        $stats_role = [ordered]@{}
        $targetrole = $Myoutput | Where-Object { $_.category -match "role" } | Group-Object -Property role | Sort-Object -Property Count -Descending | select-object -first 10
        $targetrole | ForEach-Object {
            $stats_role[$_.Name] = $_.Count
        }
        $props["targetrole"] = $stats_role
        $props["startdate"] = $startDate
        $props["enddate"] = $endDate

        # Failure analysis
        $failedActivities = $Myoutput | Where-Object { $_.result -eq 'failure' }
        $stats_failureReasons = [ordered]@{}
        $failureReasons = $failedActivities | Group-Object -Property resultReason | Sort-Object -Property Count -Descending | Select-Object -First 10
        $failureReasons | ForEach-Object {
            if ($_.Name) {
                $stats_failureReasons[$_.Name] = $_.Count
            }
        }
        $props["failureReasons"] = $stats_failureReasons

        $stats_failureUsers = [ordered]@{}
        $failureUsers = $failedActivities | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending | Select-Object -First 10
        $failureUsers | ForEach-Object {
            if ($_.Name) {
                $stats_failureUsers[$_.Name] = $_.Count
            }
        }
        $props["failureUsers"] = $stats_failureUsers

        $stats_failureRoles = [ordered]@{}
        $failureRoles = $failedActivities | Group-Object -Property role | Sort-Object -Property Count -Descending | Select-Object -First 10
        $failureRoles | ForEach-Object {
            if ($_.Name) {
                $stats_failureRoles[$_.Name] = $_.Count
            }
        }
        $props["failureRoles"] = $stats_failureRoles

        # Timeline data - group by date
        $stats_timeline = [ordered]@{}
        $Myoutput | ForEach-Object {
            $activityDate = ([DateTime]$_.activityDateTime).ToString("yyyy-MM-dd")
            if ($stats_timeline.Contains($activityDate)) {
                $stats_timeline[$activityDate]++
            } else {
                $stats_timeline[$activityDate] = 1
            }
        }
        $props["timeline"] = $stats_timeline

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
                        responsive: true,
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
                        responsive: true,
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
                        responsive: true,
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
                        responsive: true,


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
                        responsive: true,


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
        $props.targetresource.Keys | ForEach-Object {
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

                            backgroundColor: '#4fc3f7',
                            hoverOffset: 10,
                            barThickness: 40,
                            maxBarThickness: 50
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
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
                                },
                                font: { size: 18, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 16 }
                                }
                            },
                            y: {
                                ticks: { font: { size: 16 } }
                            }
                        }
                    }
                });

                const ctx7 = document.getElementById('Roles');
                new Chart(ctx7, {
                    type: 'bar',
                    data: {
                        labels: ["
        $rolesLabels = @()
        $props.targetrole.Keys | ForEach-Object {
            $rolesLabels += "'" + $_ + "'"
        }
        $myscript += ($rolesLabels -join ',')
        $myscript += "],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
        $rolesData = @()
        $props.targetrole.Keys | ForEach-Object {
            $rolesData += "'" + $props.targetrole[$_] + "'"
        }
        $myscript += ($rolesData -join ',')
        $myscript += "],

                            backgroundColor: '#ff9a9e',
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
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
                                },
                                font: { size: 18, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 16 }
                                }
                            },
                            y: {
                                ticks: {
                                    font: { size: 16 },
                                    autoSkip: false
                                }
                            }
                        }
                    }
                });

                // Timeline chart
                const ctxTimeline = document.getElementById('timeline');
                new Chart(ctxTimeline, {
                    type: 'line',
                    data: {
                        labels: ["
        $props.timeline.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                        datasets: [{
                            label: 'Activities per Day',
                            data: ["
        $props.timeline.Keys | ForEach-Object {
            $myscript += "'" + $props.timeline[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                            borderColor: '#1cd031',
                            backgroundColor: 'rgba(28, 208, 49, 0.1)',
                            fill: true,
                            tension: 0.4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: {
                                display: true,
                                position: 'top',
                                labels: { font: { size: 14 } }
                            },
                            title: {
                                display: true,
                                text: 'Activity Timeline',
                                position: 'top',
                                padding: { top: 10 },
                                font: { size: 16, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                ticks: { font: { size: 14 } }
                            },
                            y: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 14 }
                                }
                            }
                        }
                    }
                });

                // Failure Reasons chart
                const ctxFailureReasons = document.getElementById('failureReasons');
                new Chart(ctxFailureReasons, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.failureReasons.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                        datasets: [{
                            label: 'Number of Failures',
                            data: ["
        $props.failureReasons.Keys | ForEach-Object {
            $myscript += "'" + $props.failureReasons[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                            backgroundColor: '#ff6b6b',
                            hoverOffset: 10,
                            barThickness: 40,
                            maxBarThickness: 50
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        indexAxis: 'y',
                        plugins: {
                            legend: { display: false },
                            title: {
                                display: true,
                                text: 'Top Failure Reasons',
                                position: 'top',
                                padding: { top: 10 },
                                font: { size: 16, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 14 }
                                }
                            },
                            y: {
                                ticks: { font: { size: 14 } }
                            }
                        }
                    }
                });

                // Failure Users chart
                const ctxFailureUsers = document.getElementById('failureUsers');
                new Chart(ctxFailureUsers, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.failureUsers.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                        datasets: [{
                            label: 'Number of Failures',
                            data: ["
        $props.failureUsers.Keys | ForEach-Object {
            $myscript += "'" + $props.failureUsers[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                            backgroundColor: '#ffa07a',
                            hoverOffset: 10,
                            barThickness: 40,
                            maxBarThickness: 50
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        indexAxis: 'y',
                        plugins: {
                            legend: { display: false },
                            title: {
                                display: true,
                                text: 'Users with Most Failures',
                                position: 'top',
                                padding: { top: 10 },
                                font: { size: 16, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 14 }
                                }
                            },
                            y: {
                                ticks: { font: { size: 14 } }
                            }
                        }
                    }
                });

                // Failure Roles chart
                const ctxFailureRoles = document.getElementById('failureRoles');
                new Chart(ctxFailureRoles, {
                    type: 'bar',
                    data: {
                        labels: ["
        $props.failureRoles.Keys | ForEach-Object {
            $myscript += "'" + $_ + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                        datasets: [{
                            label: 'Number of Failures',
                            data: ["
        $props.failureRoles.Keys | ForEach-Object {
            $myscript += "'" + $props.failureRoles[$_] + "',"
        }
        $myscript = $myscript.Replace(",$", "")
        $myscript += "],
                            backgroundColor: '#ff8c94',
                            hoverOffset: 10,
                            barThickness: 40,
                            maxBarThickness: 50
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        indexAxis: 'y',
                        plugins: {
                            legend: { display: false },
                            title: {
                                display: true,
                                text: 'Roles with Most Failures',
                                position: 'top',
                                padding: { top: 10 },
                                font: { size: 16, weight: 'bold' }
                            }
                        },
                        scales: {
                            x: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1,
                                    font: { size: 14 }
                                }
                            },
                            y: {
                                ticks: { font: { size: 14 } }
                            }
                        }
                    }
                });

            </script>

        </body>

        </html>"

        #$myscript

        # Build chart data
        $chartData = Build-ChartData -Activities $Myoutput -StartDate $StartDate -EndDate $EndDate

        # Load template
        $templatePath = Join-Path $PSScriptRoot "..\templates\report-template.html"
        $template = Get-Content $templatePath -Raw

        # Build HTML using new architecture
        $buildParams = @{
            Template = $template
            ChartData = $chartData
            NoCodeSnippets = $NoCodeSnippets
        }
        if ($StartDate) { $buildParams['StartDate'] = $StartDate }
        if ($EndDate) { $buildParams['EndDate'] = $EndDate }

        $html = Build-ReportHTML @buildParams



        # Determine HTML file path
        if ($Path -and ($Format -eq 'HTML')) {
            # Use custom path for HTML
            $htmlPath = $Path
            # Add .html extension if not provided
            if (-not [System.IO.Path]::HasExtension($htmlPath)) {
                $htmlPath += ".html"
            }
            # Create directory if needed
            $directory = [System.IO.Path]::GetDirectoryName($htmlPath)
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
        } else {
            # Use temp directory (default behavior)
            $htmlPath = "$env:temp\PIMReport.html"
        }

        # Save HTML file
        $html | Out-File -FilePath $htmlPath -Force

        # Handle auto-opening
        if (-not $NoAutoOpen) {
            # Auto-open HTML file (default behavior)
            invoke-item $htmlPath
        } else {
            # Return object with file path when NoAutoOpen is specified
            return @{
                Data = $Myoutput
                FilePath = $htmlPath
                Format = 'HTML'
            }
        }

    }
    catch {
        MyCatch $_
    }
}

