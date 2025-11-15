# 🧪 EasyPIM Testing Documentation

**Test Coverage:** 8% (8 of 97 functions tested)  
**Test Count:** 7,323+ tests  
**Framework:** Pester 5.x  
**Status:** ✅ All tests passing  

---

## 📁 Test Organization

### Current Structure (Hybrid Migration - Nov 2025)

We've implemented a **hybrid test structure** that keeps existing tests running while building a modern test framework:

```
tests/
├── unit/                           ✅ NEW: Modern unit tests (Pester 5)
│   ├── functions/
│   │   ├── azure-resources/       # Azure Resource PIM tests
│   │   ├── entra-roles/          # Entra Role PIM tests
│   │   └── groups/               # Group PIM tests
│   └── internal/
│       └── helpers/              # Internal helper tests
├── integration/                   ✅ NEW: Integration tests (requires auth)
│   ├── azure-resources/
│   ├── entra-roles/
│   ├── groups/
│   └── orchestrator/
├── e2e/                          ✅ NEW: End-to-end workflow tests
│   └── orchestrator-workflows/
├── templates/                     ✅ NEW: Test templates
│   ├── unit-test-template.ps1
│   ├── integration-test-template.ps1
│   └── mock-patterns.ps1
├── legacy/                        # Future: Old tests being phased out
├── functions/                     📦 EXISTING: Legacy function tests (still running)
└── general/                       📦 EXISTING: Legacy validation tests (still running)
```

**Migration Strategy:** Both old and new test structures run in parallel. Zero breaking changes. See `MIGRATION-STRATEGY.md` for details.

---

## 🚀 Quick Start

### Modern Tests (Fast, Optimized) ⚡ NEW!
```powershell
# Run all modern tests (unit + integration + e2e)
.\tests\pester-modern.ps1

# Run only unit tests (fast, no auth required)
.\tests\pester-modern.ps1 -Category Unit

# Run with code coverage
.\tests\pester-modern.ps1 -Category Unit -Coverage

# Watch mode for TDD (auto-rerun on file changes)
.\tests\pester-modern.ps1 -Category Unit -Watch

# Run specific test
.\tests\pester-modern.ps1 -Path tests/unit/functions/azure-resources/
```

### Legacy Tests (Slower, Comprehensive)
```powershell
# Fast validation (general + legacy tests)
.\tests\pester.ps1 -TestGeneral $true -TestFunctions $false -Fast

# Complete test suite (requires authentication)
.\tests\pester.ps1 -TestGeneral $true -TestFunctions $true

# With code coverage
.\tests\pester.ps1 -EnableCoverage -CoverageOutputPath ".\coverage.xml"
```

### Run Specific Test Categories
```powershell
# Using optimized modern runner (RECOMMENDED) ⚡
.\tests\pester-modern.ps1 -Category Unit          # Unit tests only
.\tests\pester-modern.ps1 -Category Integration   # Integration tests
.\tests\pester-modern.ps1 -Category E2E          # E2E tests

# Using Pester directly (slower)
Invoke-Pester tests/unit          # Modern unit tests
Invoke-Pester tests/integration   # Modern integration tests
Invoke-Pester tests/e2e           # Modern E2E tests
Invoke-Pester tests/functions     # Legacy tests
```

### Watch Mode for TDD 👁️ NEW!
```powershell
# Auto-rerun tests when files change (great for TDD workflow)
.\tests\pester-modern.ps1 -Category Unit -Watch
```

---

## 📝 Writing New Tests

### Step 1: Choose Template
```powershell
# For unit tests (mocked dependencies)
Copy-Item tests/templates/unit-test-template.ps1 `
          tests/unit/functions/azure-resources/My-Function.Tests.ps1

# For integration tests (real API calls)
Copy-Item tests/templates/integration-test-template.ps1 `
          tests/integration/azure-resources/My-Function.Tests.ps1
```

### Step 2: Follow Standards
1. Replace `FunctionName` with your function
2. Update mocks (see `tests/templates/mock-patterns.ps1`)
3. Add test cases following Arrange-Act-Assert pattern
4. Ensure 80%+ code coverage

See **[TESTING-STANDARDS.md](TESTING-STANDARDS.md)** for complete guide.

---

## 📚 Documentation

- **[TESTING-STANDARDS.md](TESTING-STANDARDS.md)** - Comprehensive testing guide (800+ lines)
  - Pester 5 syntax standards
  - Mock patterns for all EasyPIM dependencies
  - Code coverage requirements
  - Test examples and best practices

- **[MIGRATION-STRATEGY.md](MIGRATION-STRATEGY.md)** - Hybrid migration plan
  - Week-by-week migration roadmap
  - Migration triggers and rules
  - Quality gates and progress tracking

- **[../TestResults/coverage-gap-report.md](../TestResults/coverage-gap-report.md)** - Coverage analysis
  - 97 functions analyzed
  - 92% coverage gap identified
  - Priority recommendations

---

## 🎯 Test Coverage Status

### Functions with Tests (8 of 97 - 8%)
✅ `Invoke-EasyPIMOrchestrator` | ✅ `Show-PIMReport` | ✅ `Get-PIMAzureResourcePolicy`  
✅ `Import-EntraRoleSettings` | ✅ `Import-Settings` | ✅ `Initialize-EasyPIMAssignments`  
✅ `get-EntraRoleConfig` | ✅ `invoke-graph`

### Priority: Critical Untested Functions (44 public)
❌ All New-*, Set-*, Remove-* cmdlets | ❌ All 12 Group PIM functions (0% coverage)  
❌ All approval workflow cmdlets | ❌ Most Get-* operations

See [coverage-gap-report.md](../TestResults/coverage-gap-report.md) for complete list.

---

## 🔧 Code Coverage

```powershell
# Enable coverage (JaCoCo format - default)
.\tests\pester.ps1 -EnableCoverage

# CoverageGutters format (VS Code extension)
.\tests\pester.ps1 -EnableCoverage -CoverageOutputFormat CoverageGutters

# Cobertura format (Azure DevOps)
.\tests\pester.ps1 -EnableCoverage -CoverageOutputFormat Cobertura
```

**Coverage Targets:** 80%+ line coverage for public functions, 100% for internal helpers.

---

## 📖 Additional Resources

- [Pester Documentation](https://pester.dev/docs/quick-start)
- [VS Code Coverage Gutters Extension](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters)
- [EasyPIM Documentation](https://kayasax.github.io/EasyPIM/)

---

**Next Steps:**
1. Review [TESTING-STANDARDS.md](TESTING-STANDARDS.md)
2. Pick a function from priority list
3. Copy appropriate template
4. Write tests following TDD (Red → Green → Refactor)
5. Achieve 80%+ coverage

**Questions?** See [TESTING-STANDARDS.md](TESTING-STANDARDS.md) Quick Reference section.