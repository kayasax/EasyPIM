function Remove-JsonComments {
	<#
	.SYNOPSIS
	Removes line and block comments from JSON content.

	.DESCRIPTION
	Processes JSON content to remove:
	- Line comments starting with //
	- Block comments /* ... */
	Respects string literals and escaped characters.

	.PARAMETER Content
	The JSON content string to process.

	.OUTPUTS
	String. The JSON content with comments removed.

	.EXAMPLE
	$cleanJson = Remove-JsonComments -Content $jsonWithComments
	#>
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Function removes multiple types of comments")]
	param([Parameter(Mandatory)][string]$Content)

	# Remove block comments first
	$noBlock = [regex]::Replace($Content, '(?s)/\*.*?\*/', '')
	
	# Remove full-line comments
	$noFullLine = [regex]::Replace($noBlock, '(?m)^[ \t]*//.*?$', '')
	
	# Process inline comments while respecting string literals
	$sb = New-Object -TypeName System.Text.StringBuilder
	foreach ($line in $noFullLine -split "`n") {
		$inString = $false
		$escaped = $false
		$out = New-Object -TypeName System.Text.StringBuilder
		
		for ($i = 0; $i -lt $line.Length; $i++) {
			$ch = $line[$i]
			
			if ($escaped) {
				[void]$out.Append($ch)
				$escaped = $false
				continue
			}
			
			if ($ch -eq '\\') {
				$escaped = $true
				[void]$out.Append($ch)
				continue
			}
			
			if ($ch -eq '"') {
				$inString = -not $inString
				[void]$out.Append($ch)
				continue
			}
			
			if (-not $inString -and $ch -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') {
				break
			}
			
			[void]$out.Append($ch)
		}
		[void]$sb.AppendLine(($out.ToString()))
	}
	
	return $sb.ToString()
}
