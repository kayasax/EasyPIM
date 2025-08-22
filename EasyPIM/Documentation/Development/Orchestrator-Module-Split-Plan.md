# Orchestrator Module Split Plan (Mono-repo)

## Scope
Create a separate PowerShell module (EasyPIM.Orchestrator) in the same repo alongside EasyPIM. The orchestrator will depend on EasyPIM public APIs, have its own manifest, tests, docs, and independent versioning/publishing.

## Deliverables
- EasyPIM.Orchestrator module folder with psd1/psm1, Public/Private functions
- Public cmdlets: Invoke-EasyPIMOrchestrator, Test-PIMPolicyDrift (and related)
- Pester tests split: tests/Core/** and tests/Orchestrator/**
- CI: build/test/publish jobs for both modules; module-scoped tags
- Docs: Orchestrator README + updated links in root docs and guides
- Back-compat shims in EasyPIM (temporary) with deprecation notes

## Timeline (business days)
- 0.5–1d: Audit coupling; define EasyPIM public API surface required
- 0.5–1d: Expose any missing public functions/parameters in EasyPIM
- 0.5d: Scaffold Orchestrator module (manifest/exports/metadata)
- 0.5–1d: CI changes (matrix per module, pack/publish, tags, cache)
- 0.5–1d: Test split, PS5.1/PS7 matrix, analyzer fixes
- 0.5d: Docs (README, examples, migration note)
- 0.5d: Shims + pre-release validation
Total: 2.5–5 days. Add 2–3 days if deep refactors are needed.

## Risks & Mitigations
- Hidden coupling to EasyPIM internals
  - Mitigate: promote required internals to public API; pin min version in RequiredModules
- Version skew between modules
  - Mitigate: CI integration tests against pinned floor and latest; module-scoped tags
- CI/publish friction
  - Mitigate: dry-run prerelease; separate publish jobs and credentials
- PS5.1 compatibility gaps
  - Mitigate: full PS5.1/PS7 matrix; analyzer gates; avoid PS7-only syntax
- Consumer breakage (import paths)
  - Mitigate: keep shims with warnings in EasyPIM for 1–2 minor versions

## CI/CD Workflow Changes
- Triggers: include both module paths (EasyPIM/** and EasyPIM.Orchestrator/**)
- Build: matrix over {core, orchestrator}; independent pack artifacts
- Tests: run Core and Orchestrator Pester suites in PS5.1 and PS7
- Publish: gated by module-scoped tags (core-vX.Y.Z, orchestrator-vX.Y.Z) or inputs
- Caching: keys per module path to avoid collisions

## Versioning & Releases
- Independent SemVer per module
- Orchestrator RequiredModules: EasyPIM (>= minimal compatible version)
- Pre-release first release of Orchestrator, then stable after validation

## Backward Compatibility
- Temporary shims in EasyPIM exporting orchestrator entry points with deprecation warnings
- Clear migration note in release notes and docs

## Decision Gate
Proceed if:
- EasyPIM public API can cover orchestrator needs without heavy refactors
- CI matrix runs clean for both modules on PS5.1 and PS7

## Rollback Plan
- Keep orchestrator functions exported in EasyPIM during rollout
- If issues arise, publish a core-only patch and revert imports while fixes are applied
