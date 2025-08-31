Describe "EasyPIM.Orchestrator module basics" {
    BeforeAll {
        $moduleRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\EasyPIM.Orchestrator")).Path
        Import-Module (Join-Path $moduleRoot "EasyPIM.Orchestrator.psd1") -Force
    }

    It "Exports public entrypoints" {
        $cmds = Get-Command -Module EasyPIM.Orchestrator | Select-Object -ExpandProperty Name
        $cmds | Should -Contain 'Invoke-EasyPIMOrchestrator'
        $cmds | Should -Contain 'Test-PIMPolicyDrift'
        $cmds | Should -Contain 'Test-PIMEndpointDiscovery'
    }

    It "Can show usage/help for Invoke-EasyPIMOrchestrator" {
        { Get-Help Invoke-EasyPIMOrchestrator -ErrorAction Stop | Out-Null } | Should -Not -Throw
    }
}
