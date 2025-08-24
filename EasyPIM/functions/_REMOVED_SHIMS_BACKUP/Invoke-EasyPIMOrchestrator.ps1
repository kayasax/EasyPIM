# Orchestrator shim for EasyPIM core module
# This function is now provided by EasyPIM.Orchestrator

# Placeholder for compatibility; will be removed in v1.10.0

function Invoke-EasyPIMOrchestrator {
    [CmdletBinding()]
    param()
    throw 'Invoke-EasyPIMOrchestrator is now part of EasyPIM.Orchestrator. Please import that module.'
}
