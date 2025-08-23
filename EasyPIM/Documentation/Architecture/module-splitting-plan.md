# EasyPIM Module Split Plan: Core vs Orchestrator

## Goals
- Separate stable core cmdlets (read/export/helpers) from higher-level Orchestrator (apply/patch/flow control)
- Enable lighter installs for audit-only scenarios; keep orchestrator optional
- Improve test surfaces and release cadence per package

## Proposed packages
- EasyPIM (existing module) — acts as Core
  - Contents: configuration helpers, discovery, Get-* commands, export/report, Test-* diagnostics
  - Dependencies: Microsoft.Graph.Authentication, Az.Accounts (read-only usage)
- EasyPIM.Orchestrator (new)
  - Contents: Invoke-EasyPIMOrchestrator, New-EPO*/Set-EPO* policy appliers, cleanup/deferred processors
  - DependsOn: EasyPIM (Core)

## Code moves (phase 1 draft)
- Keep current repo; create submodules later if needed
- Keep EasyPIM as Core (no new Core module created)
- ./EasyPIM/functions/* stay in EasyPIM (except orchestrator entrypoints)
- ./EasyPIM/internal/functions/Initialize-*, Get-*, Test-*, Show-* stay in EasyPIM
- ./EasyPIM/internal/functions/Set-EPO*, New-EPO*, Invoke-EPO* → EasyPIM.Orchestrator

## Breaking changes
- None initially; maintain re-export from umbrella module during transition

## Roadmap
- Phase 1: folder structure + build script awareness, shared tests green
- Phase 2: split manifests (EasyPIM.Core.psd1, EasyPIM.Orchestrator.psd1) with RequiredModules wiring
- Phase 3: deprecate umbrella exports; publish packages separately

## Open questions
- Versioning alignment across packages?
- Shared common internal utils location
