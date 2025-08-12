[CmdletBinding()]
Param (
	[switch]
	$SkipTest,

	[string[]]
	$CommandPath
)

if ($SkipTest) { return }

if (-not $global:testroot) { $global:testroot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

# Derive repository root (one level above tests directory)
$repoRoot = (Resolve-Path (Join-Path $global:testroot '..')).Path

# Build default command paths if not provided
if (-not $CommandPath -or $CommandPath.Count -eq 0) {
	$paths = @(
		(Join-Path $repoRoot 'EasyPIM/functions'),
		(Join-Path $repoRoot 'EasyPIM/internal/functions')
	)
	$CommandPath = @()
	foreach ($p in $paths) { if (Test-Path $p) { $CommandPath += $p } }
}

if (-not $global:__pester_data) { $global:__pester_data = @{} }
if (-not $global:__pester_data.ScriptAnalyzer) { $global:__pester_data.ScriptAnalyzer = New-Object System.Collections.ArrayList }

Describe 'Invoking PSScriptAnalyzer against commandbase' {
	$commandFiles = foreach ($path in $CommandPath) { Get-ChildItem -Path $path -Recurse | Where-Object Name -like "*.ps1" }
	$scriptAnalyzerRules = Get-ScriptAnalyzerRule

	foreach ($file in $commandFiles)
	{
		Context "Analyzing $($file.BaseName)" {
			$analysis = Invoke-ScriptAnalyzer -Path $file.FullName -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess, PSUseShouldProcessForStateChangingFunctions, PSAvoidUsingWriteHost, PSUseSingularNouns, PSUseOutputTypeCorrectly, PSReviewUnusedParameter

			forEach ($rule in $scriptAnalyzerRules)
			{
				It "Should pass $rule" -TestCases @{ analysis = $analysis; rule = $rule } {
					If ($analysis.RuleName -contains $rule)
					{
						$analysis | Where-Object RuleName -EQ $rule -outvariable failures | ForEach-Object { $null = $global:__pester_data.ScriptAnalyzer.Add($_) }

						1 | Should -Be 0
					}
					else
					{
						0 | Should -Be 0
					}
				}
			}
		}
	}
}
