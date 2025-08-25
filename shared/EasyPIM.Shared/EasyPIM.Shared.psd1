@{
    RootModule        = 'EasyPIM.Shared.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '5c4e6f5d-2f65-4b15-9b19-f0c3c6dc8b1a'
    Author            = 'EasyPIM Team'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) EasyPIM. All rights reserved.'
    Description       = 'Private shared helpers used internally by EasyPIM modules.'
    PowerShellVersion = '5.1'
    # Export a minimal set so parent modules can consume them without re-exporting publicly
    FunctionsToExport = @('Write-SectionHeader','Initialize-EasyPIMAssignments','Initialize-EasyPIMPolicies')
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('EasyPIM','Shared','Private') } }
}
