@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'EasyPIM Contributors'
    CompanyName       = 'EasyPIM'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator and policy/cleanup pipeline) (scaffold).'
    PowerShellVersion = '5.1'
    RequiredModules   = @('EasyPIM')
    FunctionsToExport = @(
        'Invoke-EasyPIMOrchestrator',
        'Test-PIMPolicyDrift'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('EasyPIM','Orchestrator','Scaffold'); ProjectUri = 'https://github.com/kayasax/EasyPIM' } }
}
