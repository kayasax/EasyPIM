# Contributing to EasyPIM

## Key Principles
- Keep production PowerShell source ASCII (no emoji) to avoid CI parser issues.
- Add tests for new features (Pester) and ensure all existing tests pass.
- Follow PowerShell naming: Verb-Noun with approved verbs.
- Use ShouldProcess for state-changing functions; suppress analyzer rules only when unavoidable with justification.

## Workflow
1. Fork and branch from `main` or appropriate feature branch.
2. Implement changes with accompanying tests under `/tests`.
3. Run local validation:
   - `pwsh -File tests/pester.ps1`
4. Update documentation (`EasyPIM/Documentation`) if behavior or parameters change.
5. Update module version in the manifest for user-facing changes.
6. Submit PR including summary of changes and validation results.

## Style
- 4 spaces indentation.
- `$null -eq $var` style for null comparisons.
- Prefer `Write-Verbose` over `Write-Host` unless user-facing progress.
- Avoid empty catch blocks; log via `Write-Verbose`.

## Testing
- Add focused unit / integration tests; avoid brittle timing assumptions.
- Keep exported artifacts out of source control (see `.gitignore`).

## Encoding
- `.gitattributes` enforces LF and UTF-8; do not commit with BOM unless required.

## Security
- Never commit secrets. Use environment variables or Azure Key Vault references.

Thanks for contributing!
