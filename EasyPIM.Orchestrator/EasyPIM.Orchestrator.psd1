@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = '22222222-2222-2222-2222-222222222222'
    Author            = 'EasyPIM Contributors'
    CompanyName       = 'EasyPIM'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator and policy/cleanup pipeline) (scaffold).'
    PowerShellVersion = '5.1'
    RequiredModules   = @()
    FunctionsToExport = @(
        'Invoke-EasyPIMOrchestrator',
        'Test-PIMPolicyDrift'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('EasyPIM','Orchestrator','Scaffold'); ProjectUri = 'https://github.com/kayasax/EasyPIM' } }
}
