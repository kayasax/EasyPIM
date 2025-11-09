<#
.SYNOPSIS
    Creates an ECharts configuration object

.DESCRIPTION
    Factory function to create ECharts configurations
    
.PARAMETER Type
    Chart type: 'pie', 'bar', 'line'
    
.PARAMETER Data
    Ordered hashtable of labels and values
    
.PARAMETER Title
    Chart title
    
.PARAMETER Horizontal
    For bar charts, makes them horizontal
    
.PARAMETER BackgroundColor
    Custom background color
    
.EXAMPLE
    New-EChartsConfig -Type 'pie' -Data $data -Title 'Status'
#>
function New-EChartsConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('pie', 'bar', 'line')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Data,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [switch]$Horizontal,
        
        [string]$BackgroundColor
    )
    
    $labels = @($Data.Keys)
    $values = @($Data.Values)
    
    $config = [ordered]@{
        title = @{
            text = $Title
            left = 'center'
            textStyle = @{
                color = '#DDDDDD'
                fontSize = 18
            }
        }
        tooltip = @{
            trigger = if ($Type -eq 'pie') { 'item' } else { 'axis' }
        }
        backgroundColor = 'transparent'
    }
    
    switch ($Type) {
        'pie' {
            $pieData = @()
            $colors = @('#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF', '#FF9F40', '#8DD1E1', '#D4A5A5', '#A5D4D4', '#D4A5C4')
            for ($i = 0; $i -lt $labels.Count; $i++) {
                $pieData += @{
                    name = $labels[$i]
                    value = $values[$i]
                    itemStyle = @{
                        color = $colors[$i % $colors.Count]
                    }
                }
            }
            
            $config.legend = @{
                show = $false
            }
            $config.series = @(
                @{
                    type = 'pie'
                    radius = '55%'
                    center = @('50%', '50%')
                    data = $pieData
                    label = @{
                        color = '#DDDDDD'
                        fontSize = 14
                    }
                }
            )
        }
        'bar' {
            $config.grid = @{
                left = '15%'
                right = '5%'
                bottom = '10%'
                top = '15%'
            }
            
            if ($Horizontal) {
                $config.xAxis = @{
                    type = 'value'
                    axisLabel = @{ color = '#ffff99' }
                }
                $config.yAxis = @{
                    type = 'category'
                    data = $labels
                    axisLabel = @{ color = '#ffff99' }
                }
            } else {
                $config.xAxis = @{
                    type = 'category'
                    data = $labels
                    axisLabel = @{ color = '#ffff99' }
                }
                $config.yAxis = @{
                    type = 'value'
                    axisLabel = @{ color = '#ffff99' }
                }
            }
            
            $config.series = @(
                @{
                    type = 'bar'
                    data = $values
                    barMaxWidth = 40
                    barCategoryGap = '30%'
                    itemStyle = @{
                        color = if ($BackgroundColor) { $BackgroundColor } else { '#4fc3f7' }
                    }
                }
            )
        }
        'line' {
            $config.grid = @{
                left = '10%'
                right = '5%'
                bottom = '10%'
                top = '15%'
            }
            $config.xAxis = @{
                type = 'category'
                boundaryGap = $false
                data = $labels
                axisLabel = @{ color = '#ffff99' }
            }
            $config.yAxis = @{
                type = 'value'
                axisLabel = @{ color = '#ffff99' }
            }
            $config.series = @(
                @{
                    type = 'line'
                    data = $values
                    smooth = $true
                    itemStyle = @{ color = '#1cd031' }
                    areaStyle = @{ color = 'rgba(28, 208, 49, 0.3)' }
                }
            )
        }
    }
    
    return $config
}
