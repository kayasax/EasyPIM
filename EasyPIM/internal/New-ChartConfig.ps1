<#
.SYNOPSIS
    Creates a Chart.js configuration object

.DESCRIPTION
    Factory function to create consistent Chart.js configurations for different chart types
    
.PARAMETER Type
    Chart type: 'pie', 'bar', 'line'
    
.PARAMETER Data
    Ordered hashtable of labels and values
    
.PARAMETER Title
    Chart title
    
.PARAMETER Horizontal
    For bar charts, makes them horizontal (indexAxis: 'y')
    
.PARAMETER BackgroundColor
    Custom background color(s)
    
.EXAMPLE
    New-ChartConfig -Type 'pie' -Data $data -Title 'Status'
#>
function New-ChartConfig {
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
        
        [string]$BackgroundColor,
        
        [string]$Theme = 'dark'
    )
    
    $labels = @($Data.Keys)
    $values = @($Data.Values)
    
    $config = [ordered]@{
        type = $Type
        data = @{
            labels = $labels
            datasets = @(
                @{
                    label = 'Count'
                    data = $values
                    hoverOffset = 10
                }
            )
        }
        options = @{
            responsive = $true
            plugins = @{
                legend = @{
                    display = $true
                    labels = @{
                        color = '#ffff99'
                        font = @{ size = 14 }
                    }
                }
                title = @{
                    display = $true
                    text = $Title
                    position = 'top'
                    padding = @{ top = 10 }
                    font = @{ size = 18; weight = 'bold' }
                    color = '#DDDDDD'
                }
            }
        }
    }
    
    # Type-specific configurations
    switch ($Type) {
        'pie' {
            $config.options.radius = 70
            $config.options.plugins.legend.position = 'right'
            
            # Color palette for consistency
            $config.data.datasets[0].backgroundColor = if ($BackgroundColor) { 
                $BackgroundColor 
            } else { 
                @(
                    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
                    '#FF9F40', '#FF6384', '#C9CBCF', '#4BC0C0', '#FF6384',
                    '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF', '#FF9F40'
                )
            }
        }
        'bar' {
            $config.options.maintainAspectRatio = $false
            
            if ($Horizontal) {
                $config.options.indexAxis = 'y'
            }
            
            $config.options.scales = @{
                x = @{
                    beginAtZero = $true
                    ticks = @{
                        stepSize = 1
                        font = @{ size = 16 }
                        color = '#ffff99'
                    }
                }
                y = @{
                    ticks = @{
                        font = @{ size = 16 }
                        color = '#ffff99'
                        autoSkip = $false
                    }
                }
            }
            
            
            if ($Horizontal) {
                # Swap x and y for horizontal bars
                $temp = $config.options.scales.x
                $config.options.scales.x = $config.options.scales.y
                $config.options.scales.y = $temp
            }
            
            $config.data.datasets[0].backgroundColor = if ($BackgroundColor) { $BackgroundColor } else { '#4fc3f7' }
        }
        'line' {
            $config.options.maintainAspectRatio = $false
            $config.options.scales = @{
                x = @{
                    ticks = @{
                        font = @{ size = 14 }
                        color = '#ffff99'
                    }
                }
                y = @{
                    beginAtZero = $true
                    ticks = @{
                        stepSize = 1
                        font = @{ size = 14 }
                        color = '#ffff99'
                    }
                }
            }
            
            $config.data.datasets[0].borderColor = '#1cd031'
            $config.data.datasets[0].backgroundColor = 'rgba(28,208,49,0.1)'
            $config.data.datasets[0].fill = $true
            $config.data.datasets[0].tension = 0.4
        }
    }
    
    return $config
}
