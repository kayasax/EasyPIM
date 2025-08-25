$originalErrorAction = $ErrorActionPreference
try {
	if (-not $global:testroot) { $global:testroot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
} catch {
	throw "Failed to establish test root: $($_.Exception.Message)"
}

$moduleRoot = (Resolve-Path (Join-Path $global:testroot '..')).Path

$exceptionsFile = Join-Path $global:testroot 'general\FileIntegrity.Exceptions.ps1'
if (Test-Path $exceptionsFile) {
	. $exceptionsFile
} else {
	Write-Warning "FileIntegrity.Exceptions.ps1 not found under $global:testroot/general; proceeding with default (no bans)."
	if (-not $global:BannedCommands) { $global:BannedCommands = @() }
	if (-not $global:MayContainCommand) { $global:MayContainCommand = @{} }
}

Describe "Verifying integrity of module files" {
	BeforeAll {
		# Detect Pester version for cross-version compatibility
		$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
		$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
		$isLegacyPester = $pesterVersion.Major -lt 5

		function Get-FileEncoding
		{
		<#
			.SYNOPSIS
				Tests a file for encoding.

			.DESCRIPTION
				Tests a file for encoding.

			.PARAMETER Path
				The file to test
		#>
			[CmdletBinding()]
			Param (
				[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
				[Alias('FullName')]
				[string]
				$Path
			)

			if ($PSVersionTable.PSVersion.Major -lt 6)
			{
				[byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
			}
			else
			{
				[byte[]]$byte = Get-Content -AsByteStream -ReadCount 4 -TotalCount 4 -Path $Path
			}

			# Handle empty or very short files safely
			if (-not $byte -or $byte.Length -lt 4) { return 'Unknown' }

			if ($byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf) { 'UTF8 BOM' }
			elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) { 'Unicode' }
			elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) { 'UTF32' }
			elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) { 'UTF7' }
			else { 'Unknown' }
		}
	}

	Context "Validating PS1 Script files" {
		$testFolder = Join-Path $moduleRoot 'TEST'
		$allFiles = Get-ChildItem -Path $moduleRoot -Recurse -File |
			Where-Object { $_.Name -like '*.ps1' } |
			Where-Object { $_.FullName -notlike (Join-Path $moduleRoot 'tests\*') } |
			Where-Object { $_.FullName -notlike (Join-Path $moduleRoot 'functions\_REMOVED_SHIMS_BACKUP\*') } |
			Where-Object { $_.FullName -notlike (Join-Path $moduleRoot 'backup\_REMOVED_SHIMS_BACKUP\*') } |
			Where-Object { $_.FullName -notlike (Join-Path $testFolder '*') }
		$testFiles = @()
		if (Test-Path $testFolder) { $testFiles = Get-ChildItem -Path $testFolder -Recurse -File }
		if ($testFiles.Count -gt 0) { $allFiles = $allFiles | Where-Object { $_.FullName -notin ($testFiles | ForEach-Object FullName) } }

		$testRootPrefix = ((Join-Path $moduleRoot 'TEST') + '\\').ToLowerInvariant()
		foreach ($file in $allFiles)
		{
			if ( ($file.FullName.ToLowerInvariant()).StartsWith($testRootPrefix) ) { continue }
			$name = $file.FullName.Replace("$moduleRoot\", '')

			It "[$name] Should have UTF8 (BOM optional)" -TestCases @{ file = $file } {
				# Detect Pester version for cross-version compatibility within test
				$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
				$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
				$isLegacyPester = $pesterVersion.Major -lt 5

				if ($isLegacyPester) {
					$encoding = Get-FileEncoding -Path $file.FullName
					$encoding | Should Match '^(UTF8 BOM|Unknown)$'
				} else {
					(Get-FileEncoding -Path $file.FullName) | Should -BeIn @('UTF8 BOM','Unknown')
				}
			}

			It "[$name] Should have no trailing space" -TestCases @{ file = $file } {
				# Detect Pester version for cross-version compatibility within test
				$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
				$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
				$isLegacyPester = $pesterVersion.Major -lt 5

				if ($isLegacyPester) {
					($file | Select-String "\s$" | Where-Object { $_.Line.Trim().Length -gt 0}).LineNumber | Should BeNullOrEmpty
				} else {
					($file | Select-String "\s$" | Where-Object { $_.Line.Trim().Length -gt 0}).LineNumber | Should -BeNullOrEmpty
				}
			}

			$tokens = $null
			$parseErrors = $null
			$null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

			It "[$name] Should have no syntax errors" -TestCases @{ parseErrors = $parseErrors } {
				# Detect Pester version for cross-version compatibility within test
				$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
				$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
				$isLegacyPester = $pesterVersion.Major -lt 5

				if ($isLegacyPester) {
					$parseErrors | Should BeNullOrEmpty
				} else {
					$parseErrors | Should -BeNullOrEmpty
				}
			}

			foreach ($command in $global:BannedCommands)
			{
				if ($global:MayContainCommand["$command"] -notcontains $file.Name)
				{
					It "[$name] Should not use $command" -TestCases @{ tokens = $tokens; command = $command } {
						# Detect Pester version for cross-version compatibility within test
						$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
						$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
						$isLegacyPester = $pesterVersion.Major -lt 5

						if ($isLegacyPester) {
							$tokens | Where-Object Text -EQ $command | Should BeNullOrEmpty
						} else {
							$tokens | Where-Object Text -EQ $command | Should -BeNullOrEmpty
						}
					}
				}
			}
		}
	}

	Context "Validating help.txt help files" {
		$testFolder = Join-Path $moduleRoot 'TEST'
		$allFiles = Get-ChildItem -Path $moduleRoot -Recurse -File |
			Where-Object { $_.Name -like '*.help.txt' } |
			Where-Object { $_.FullName -notlike (Join-Path $moduleRoot 'tests\*') } |
			Where-Object { $_.FullName -notlike (Join-Path $testFolder '*') }
		$testFiles = @()
		if (Test-Path $testFolder) { $testFiles = Get-ChildItem -Path $testFolder -Recurse -File }
		if ($testFiles.Count -gt 0) { $allFiles = $allFiles | Where-Object { $_.FullName -notin ($testFiles | ForEach-Object FullName) } }

		$testRootPrefix = ((Join-Path $moduleRoot 'TEST') + '\\').ToLowerInvariant()
		foreach ($file in $allFiles)
		{
			if ( ($file.FullName.ToLowerInvariant()).StartsWith($testRootPrefix) ) { continue }
			$name = $file.FullName.Replace("$moduleRoot\", '')

			It "[$name] Should have UTF8 encoding" -TestCases @{ file = $file } {
				# Detect Pester version for cross-version compatibility within test
				$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
				$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
				$isLegacyPester = $pesterVersion.Major -lt 5

				if ($isLegacyPester) {
					Get-FileEncoding -Path $file.FullName | Should Be 'UTF8 BOM'
				} else {
					Get-FileEncoding -Path $file.FullName | Should -Be 'UTF8 BOM'
				}
			}

			It "[$name] Should have no trailing space" -TestCases @{ file = $file } {
				# Detect Pester version for cross-version compatibility within test
				$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
				$pesterVersion = if ($pesterModule) { $pesterModule.Version } else { [Version]'0.0' }
				$isLegacyPester = $pesterVersion.Major -lt 5

				if ($isLegacyPester) {
					($file | Select-String "\s$" | Where-Object { $_.Line.Trim().Length -gt 0 } | Measure-Object).Count | Should Be 0
				} else {
					($file | Select-String "\s$" | Where-Object { $_.Line.Trim().Length -gt 0 } | Measure-Object).Count | Should -Be 0
				}
			}
		}
	}
}
