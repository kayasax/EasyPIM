Describe "Validating the module manifest" {
	$moduleRoot = (Resolve-Path "$global:testroot\..\EasyPIM").Path
	$manifest = ((Get-Content "$moduleRoot\EasyPIM.psd1") -join "`n") | Invoke-Expression
	Context "Basic resources validation" {
		$files = Get-ChildItem "$moduleRoot\functions" -Recurse -File | Where-Object Name -like "*.ps1"
		It "Exports all functions in the public folder" -TestCases @{ files = $files; manifest = $manifest } {

			$functions = (Compare-Object -ReferenceObject $files.BaseName -DifferenceObject $manifest.FunctionsToExport | Where-Object SideIndicator -Like '<=').InputObject
			$functions | Should -BeNullOrEmpty
		}
		It "Exports no function that isn't also present in the public folder" -TestCases @{ files = $files; manifest = $manifest } {
			$functions = (Compare-Object -ReferenceObject $files.BaseName -DifferenceObject $manifest.FunctionsToExport | Where-Object SideIndicator -Like '=>').InputObject
			$functions | Should -BeNullOrEmpty
		}

		It "Exports none of its internal functions" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			$files = Get-ChildItem "$moduleRoot\internal\functions" -Recurse -File -Filter "*.ps1"
			# Filter out shim placeholder files that do NOT actually declare a function of the same name
			$actualInternalFunctionFiles = foreach ($f in $files) {
				$bn = $f.BaseName
				if ($manifest.FunctionsToExport -notcontains $bn) { continue }
				$content = (Get-Content -Path $f.FullName -Raw -ErrorAction SilentlyContinue)
				if ($content -match "function\s+$bn\b") { $f }
			}
			$actualInternalFunctionFiles | Should -BeNullOrEmpty
		}
	}

	Context "Individual file validation" {
		It "The root module file exists" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			Test-Path "$moduleRoot\$($manifest.RootModule)" | Should -Be $true
		}

		foreach ($format in $manifest.FormatsToProcess)
		{
			It "The file $format should exist" -TestCases @{ moduleRoot = $moduleRoot; format = $format } {
				Test-Path "$moduleRoot\$format" | Should -Be $true
			}
		}

		foreach ($type in $manifest.TypesToProcess)
		{
			It "The file $type should exist" -TestCases @{ moduleRoot = $moduleRoot; type = $type } {
				Test-Path "$moduleRoot\$type" | Should -Be $true
			}
		}

		foreach ($assembly in $manifest.RequiredAssemblies)
		{
            if ($assembly -like "*.dll") {
                It "The file $assembly should exist" -TestCases @{ moduleRoot = $moduleRoot; assembly = $assembly } {
                    Test-Path "$moduleRoot\$assembly" | Should -Be $true
                }
            }
            else {
                It "The file $assembly should load from the GAC" -TestCases @{ moduleRoot = $moduleRoot; assembly = $assembly } {
                    { Add-Type -AssemblyName $assembly } | Should -Not -Throw
                }
            }
        }

		foreach ($tag in $manifest.PrivateData.PSData.Tags)
		{
			It "Tags should have no spaces in name" -TestCases @{ tag = $tag } {
				$tag -match " " | Should -Be $false
			}
		}
	}
}
