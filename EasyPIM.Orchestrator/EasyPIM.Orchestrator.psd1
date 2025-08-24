@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion     = '0.1.0-beta1'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'Loïc MICHEL'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) loicmichel. All rights reserved.'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator)'
    PowerShellVersion = '5.1'
    RequiredModules   = @('EasyPIM')
    FunctionsToExport = @(
        'Invoke-EasyPIMOrchestrator',
        'Test-PIMPolicyDrift',
        'Test-PIMEndpointDiscovery'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{
        Tags = @('EasyPIM','Orchestrator')
        ProjectUri = 'https://github.com/kayasax/EasyPIM'
        LicenseUri = 'https://github.com/kayasax/EasyPIM/blob/main/LICENSE'
        ReleaseNotes = @'
        PRE-RELEASE: This is a beta version of the EasyPIM.Orchestrator module. It is not intended for production use and may change without notice.
        Use for testing and feedback only. Breaking changes may occur before the first stable release.
        '@
    } }
}
