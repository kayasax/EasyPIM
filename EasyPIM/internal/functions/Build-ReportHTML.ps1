<#
.SYNOPSIS
    Loads the HTML report template

.DESCRIPTION
    Reads the HTML template file from the module templates directory
    
.EXAMPLE
    Get-ReportTemplate
#>
function Get-ReportTemplate {
    [CmdletBinding()]
    param()
    
    $templatePath = Join-Path $PSScriptRoot "..\templates\report-template.html"
    
    if (-not (Test-Path $templatePath)) {
        throw "Template file not found: $templatePath"
    }
    
    return Get-Content $templatePath -Raw
}

<#
.SYNOPSIS
    Builds the complete HTML report

.DESCRIPTION
    Injects chart configurations and data into the HTML template
    
.PARAMETER Template
    HTML template string
    
.PARAMETER ChartData
    Hashtable of chart data from Build-ChartData
    
.PARAMETER NoCodeSnippets
    Hide description sections with code examples
    
.EXAMPLE
    Build-ReportHTML -Template $template -ChartData $data
#>
function Build-ReportHTML {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [Parameter(Mandatory)]
        [hashtable]$ChartData,
        
        [switch]$NoCodeSnippets,
        
        [datetime]$StartDate,
        
        [datetime]$EndDate
    )
    
    # Build date range display
    $dateRangeHTML = ""
    if ($StartDate -and $EndDate) {
        $dateRangeHTML = @"
<div style="text-align: center; padding: 15px; background: rgba(255,255,255,0.05); border-radius: 8px; margin-bottom: 20px;">
    <strong>📅 Showing activities from $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))</strong>
</div>
"@
    }
    
    # Build summary tiles
    $tilesHTML = @"
<div class="summary-tiles">
    <div class="tile">
        <div class="tile-label">Total Activities</div>
        <div class="tile-value">$($ChartData.totalActivities)</div>
    </div>
    <div class="tile">
        <div class="tile-label">Success Rate</div>
        <div class="tile-value">$($ChartData.successRate)%</div>
    </div>
    <div class="tile">
        <div class="tile-label">Unique Users</div>
        <div class="tile-value">$($ChartData.uniqueUsers)</div>
    </div>
    <div class="tile">
        <div class="tile-label">Time Period</div>
        <div class="tile-value">$($ChartData.timePeriodDays) days</div>
    </div>
</div>
"@
    
    # Define chart configurations with optional description sections
    $chartConfigs = @(
        @{
            id = 'categoryChart'
            type = 'pie'
            data = $ChartData.category
            title = 'Category Distribution'
            sectionTitle = '📊 ACTIVITY RESULTS'
            sectionStyle = 'background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white;'
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    filter the activity for a specific category:<br>
    <pre><code>&#36;r | where-object &#123; &#36;_.category -eq "GroupManagement" &#125;</code></pre>
</div>
'@
            }
        }
        @{
            id = 'resultChart'
            type = 'pie'
            data = $ChartData.result
            title = 'Result Status'
            sectionTitle = '✅ STATUS BREAKDOWN'
            sectionStyle = 'background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); color: white;'
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    consult the failed operations:<br>
    <code>&#36;r | where-object &#123;&#36;_.result -eq "Failure"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'activityChart'
            type = 'pie'
            data = $ChartData.activity
            title = 'Activity Types'
            sectionTitle = '🎯 ACTIVITY TYPES'
            sectionStyle = 'background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); color: white;'
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    consult the details:<br>
    <code>&#36;r | where-object &#123;&#36;_.activityDisplayName -eq "Add member to role in PIM requested (timebound)"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'requestorChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.requestor
            title = 'Top 10 Requestors'
            sectionTitle = '👥 TOP REQUESTORS'
            sectionStyle = 'background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white;'
            height = [Math]::Max(300, $ChartData.requestor.Count * 60 + 100)
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    filter the activity requested by User1:<br>
    <code>&#36;r | where-object &#123;&#36;_.Initiatedby -match "user1"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'groupsChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.targetgroups
            title = 'Top 10 Groups Requested'
            sectionTitle = '👤 TOP GROUPS REQUESTED'
            sectionStyle = 'background: linear-gradient(135deg, #30cfd0 0%, #330867 100%); color: white;'
            height = [Math]::Max(300, $ChartData.targetgroups.Count * 60 + 100)
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    get the details for a group:<br>
    <code>&#36;r | where-object &#123;&#36;_.category -match "group" -and &#36;_.targetresources -eq "PIM_GuestAdmins"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'azureRolesChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.targetresource
            title = 'Top 10 Azure Roles Requested'
            sectionTitle = '☁️ TOP AZURE ROLES REQUESTED'
            sectionStyle = 'background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); color: #333;'
            backgroundColor = '#4fc3f7'
            height = [Math]::Max(300, $ChartData.targetresource.Count * 60 + 100)
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    consult the details for a specific Azure role:<br>
    <code>&#36;r | where-object &#123;&#36;_.category -match "resource" -and &#36;_.role -eq "Reader"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'entraRolesChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.targetrole
            title = 'Top 10 Entra Roles Requested'
            sectionTitle = '🔐 TOP ENTRA ROLES REQUESTED'
            sectionStyle = 'background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%); color: #333;'
            backgroundColor = '#ff9a9e'
            height = [Math]::Max(300, $ChartData.targetrole.Count * 60 + 100)
            description = if (-not $NoCodeSnippets) {
                @'
<div class="description">
    Assuming this page was generated with <code>&#36;r=show-PIMreport</code>, you can use the following code to
    consult the details for a specific Entra role:<br>
    <code>&#36;r | where-object &#123;&#36;_.category -match "role" -and &#36;_.role -eq "Global Administrator"&#125;</code>
</div>
'@
            }
        }
        @{
            id = 'timelineChart'
            type = 'line'
            data = $ChartData.timeline
            title = 'Activity Timeline'
            sectionTitle = '📊 ACTIVITY TIMELINE'
            sectionStyle = 'background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;'
        }
        @{
            id = 'failureReasonsChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.failureReasons
            title = 'Top Failure Reasons'
            sectionTitle = '⚠️ FAILURE ANALYSIS'
            sectionStyle = 'background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%); color: white;'
            backgroundColor = '#ff6b6b'
            height = [Math]::Max(300, $ChartData.failureReasons.Count * 60 + 100)
            isFirstInSection = $true
        }
        @{
            id = 'failureUsersChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.failureUsers
            title = 'Users with Most Failures'
            backgroundColor = '#ffa07a'
            height = [Math]::Max(300, $ChartData.failureUsers.Count * 60 + 100)
        }
        @{
            id = 'failureRolesChart'
            type = 'bar'
            horizontal = $true
            data = $ChartData.failureRoles
            title = 'Roles with Most Failures'
            backgroundColor = '#ff8c94'
            height = [Math]::Max(300, $ChartData.failureRoles.Count * 60 + 100)
        }
    )
    
    # Generate HTML for charts
    $chartsHTML = ""
    $chartScripts = ""
    
    foreach ($config in $chartConfigs) {
        if ($config.data.Count -eq 0) {
            continue
        }
        
        # Add section header if specified
        if ($config.sectionTitle) {
            $chartsHTML += "<h2 class='section-header' style='$($config.sectionStyle)'>$($config.sectionTitle)</h2>`n"
        }
        
        # Determine container class and height
        $containerClass = switch ($config.type) {
            'pie' { 'pie' }
            'line' { 'line' }
            'bar' { 'bar' }
        }
        
        $heightStyle = if ($config.height) { "height: $($config.height)px;" } else { "" }
        
        # Generate chart HTML for ECharts with optional description
        $descriptionHTML = if ($config.description) { $config.description } else { "" }
        
        $chartsHTML += @"
<div class="chart-row">
    <div class="chart-container $containerClass" style="$heightStyle">
        <div id="$($config.id)" class="chart"></div>
    </div>
    $descriptionHTML
</div>

"@
        
        # Generate chart configuration using ECharts (function is auto-loaded from internal/functions)
        $horizontal = if ($config.horizontal) { $true } else { $false }
        $chartConfigObj = New-EChartsConfig -Type $config.type -Data $config.data -Title $config.title -Horizontal:$horizontal
        
        if ($config.backgroundColor -and $config.type -ne 'pie') {
            $chartConfigObj.series[0].itemStyle.color = $config.backgroundColor
        }
        
        $configJson = ($chartConfigObj | ConvertTo-Json -Depth 10 -Compress) -replace '[\r\n]+', ' '
        
        # Generate chart script for ECharts
        $chartScripts += @"
        
        // $($config.title)
        var chart_$($config.id) = echarts.init(document.getElementById('$($config.id)'));
        chart_$($config.id).setOption($configJson);
        
"@
    }
    
    # Replace placeholders
    $html = $Template
    $html = $html -replace '<!-- PLACEHOLDER_SUMMARY_TILES -->', $tilesHTML
    $html = $html -replace '<!-- PLACEHOLDER_DATE_RANGE -->', $dateRangeHTML
    $html = $html -replace '<!-- PLACEHOLDER_CHARTS -->', $chartsHTML
    $html = $html -replace '<!-- PLACEHOLDER_DATE -->', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $html = $html -replace '// PLACEHOLDER_CHART_SCRIPTS', $chartScripts
    
    return $html
}
