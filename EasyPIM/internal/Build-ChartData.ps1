<#
.SYNOPSIS
    Builds chart data structures from PIM activity data

.DESCRIPTION
    Processes PIM activity arrays and creates ordered hashtables for chart consumption
    
.PARAMETER Activities
    Array of PIM activity objects
    
.PARAMETER StartDate
    Optional start date filter
    
.PARAMETER EndDate
    Optional end date filter
    
.EXAMPLE
    Build-ChartData -Activities $myActivities
#>
function Build-ChartData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Activities,
        
        [datetime]$StartDate,
        
        [datetime]$EndDate
    )
    
    # Apply date filtering if specified
    if ($StartDate -or $EndDate) {
        $Activities = $Activities | Where-Object {
            $activityDate = [datetime]$_.activityDateTime
            $include = $true
            
            if ($StartDate) {
                $include = $include -and ($activityDate -ge $StartDate)
            }
            
            if ($EndDate) {
                $include = $include -and ($activityDate -le $EndDate)
            }
            
            $include
        }
    }
    
    $chartData = @{}
    
    # Category distribution
    $stats_category = [ordered]@{}
    $Activities | Group-Object -Property category | ForEach-Object {
        $stats_category[$_.Name] = $_.Count
    }
    $chartData['category'] = $stats_category
    
    # Result distribution
    $stats_result = [ordered]@{}
    $Activities | Group-Object -Property result | ForEach-Object {
        $stats_result[$_.Name] = $_.Count
    }
    $chartData['result'] = $stats_result
    
    # Activity type distribution (using activityDisplayName with fallback)
    $stats_activity = [ordered]@{}
    $Activities | ForEach-Object {
        # Fallback chain: activityDisplayName -> activity -> operationType
        $activityName = if ($_.activityDisplayName) { 
            $_.activityDisplayName 
        } elseif ($_.activity) { 
            $_.activity 
        } else { 
            $_.operationType 
        }
        
        # Group and count
        if ($activityName -and $activityName -notmatch 'completed') {
            if ($stats_activity.Contains($activityName)) {
                $stats_activity[$activityName]++
            } else {
                $stats_activity[$activityName] = 1
            }
        }
    }
    $chartData['activity'] = $stats_activity
    
    # Top requestors
    $stats_requestor = [ordered]@{}
    $requestors = $Activities | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending | Select-Object -First 10
    $requestors | ForEach-Object {
        $stats_requestor[$_.Name] = $_.Count
    }
    $chartData['requestor'] = $stats_requestor
    
    # Top groups
    $stats_groups = [ordered]@{}
    $groups = $Activities | Where-Object { $_.category -match "group" } | Group-Object -Property targetResources | Sort-Object -Property Count -Descending | Select-Object -First 10
    $groups | ForEach-Object {
        $stats_groups[$_.Name] = $_.Count
    }
    $chartData['targetgroups'] = $stats_groups
    
    # Top Azure resources
    $stats_resource = [ordered]@{}
    $resources = $Activities | Where-Object { $_.category -match "resource" } | Group-Object -Property role | Sort-Object -Property Count -Descending | Select-Object -First 10
    $resources | ForEach-Object {
        $stats_resource[$_.Name] = $_.Count
    }
    $chartData['targetresource'] = $stats_resource
    
    # Top Entra roles
    $stats_role = [ordered]@{}
    $roles = $Activities | Where-Object { $_.category -match "role" } | Group-Object -Property role | Sort-Object -Property Count -Descending | Select-Object -First 10
    $roles | ForEach-Object {
        $stats_role[$_.Name] = $_.Count
    }
    $chartData['targetrole'] = $stats_role
    
    # Timeline data
    $stats_timeline = [ordered]@{}
    $Activities | ForEach-Object {
        $date = ([datetime]$_.activityDateTime).ToString('yyyy-MM-dd')
        if ($stats_timeline.Contains($date)) {
            $stats_timeline[$date]++
        } else {
            $stats_timeline[$date] = 1
        }
    }
    # Sort timeline by date
    $sortedTimeline = [ordered]@{}
    $stats_timeline.Keys | Sort-Object | ForEach-Object {
        $sortedTimeline[$_] = $stats_timeline[$_]
    }
    $chartData['timeline'] = $sortedTimeline
    
    # Failure analysis
    $failedActivities = $Activities | Where-Object { $_.result -eq 'failure' }
    
    $stats_failureReasons = [ordered]@{}
    $failureReasons = $failedActivities | Group-Object -Property resultReason | Sort-Object -Property Count -Descending | Select-Object -First 10
    $failureReasons | ForEach-Object {
        if ($_.Name) {
            $stats_failureReasons[$_.Name] = $_.Count
        }
    }
    $chartData['failureReasons'] = $stats_failureReasons
    
    $stats_failureUsers = [ordered]@{}
    $failureUsers = $failedActivities | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending | Select-Object -First 10
    $failureUsers | ForEach-Object {
        if ($_.Name) {
            $stats_failureUsers[$_.Name] = $_.Count
        }
    }
    $chartData['failureUsers'] = $stats_failureUsers
    
    $stats_failureRoles = [ordered]@{}
    $failureRoles = $failedActivities | Group-Object -Property role | Sort-Object -Property Count -Descending | Select-Object -First 10
    $failureRoles | ForEach-Object {
        if ($_.Name) {
            $stats_failureRoles[$_.Name] = $_.Count
        }
    }
    $chartData['failureRoles'] = $stats_failureRoles
    
    # Summary statistics
    $chartData['totalActivities'] = $Activities.Count
    $successCount = ($Activities | Where-Object { $_.result -eq 'success' }).Count
    $chartData['successRate'] = if ($Activities.Count -gt 0) { 
        [math]::Round(($successCount / $Activities.Count) * 100, 1) 
    } else { 
        0 
    }
    $chartData['uniqueUsers'] = ($Activities | Select-Object -Property requestor -Unique).Count
    
    if ($StartDate -and $EndDate) {
        $chartData['timePeriodDays'] = ($EndDate - $StartDate).Days
    } else {
        $dates = $Activities | ForEach-Object { [datetime]$_.activityDateTime }
        if ($dates.Count -gt 0) {
            $minDate = ($dates | Measure-Object -Minimum).Minimum
            $maxDate = ($dates | Measure-Object -Maximum).Maximum
            $chartData['timePeriodDays'] = ($maxDate - $minDate).Days
        } else {
            $chartData['timePeriodDays'] = 0
        }
    }
    
    return $chartData
}
