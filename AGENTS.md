# powershell-modules

Independently versioned PowerShell modules, `TaffarelJr.<Name>`, each meant
for the PowerShell Gallery. Sources are under `src/<ModuleName>/`, tests mirror
them under `test/<ModuleName>/`, and each module's README says what it does.

## Rules

- PowerShell 7.4 only: every file that runs or imports alone opens with
  `#Requires -Version 7.4`, and every manifest says `PowerShellVersion = '7.4'`
  and `CompatiblePSEditions = @('Core')`.
- Files are UTF-8 without a BOM, with CRLF line endings.
- Aim for 80 columns, 120 at most; break a long call at parameter boundaries
  or splat it. No comments except a non-obvious reason, on the line it explains.
- Functions stream their results one at a time (`return $results`, callers
  wrap in `@()`), never a leading-comma array.
- `PSScriptAnalyzerSettings.psd1` (root for `src`, `test/` for the tests) is
  the mechanical rule: a change leaves the analyzer clean on every file it
  touches, and a suppression carries a true justification.
- Every exported function has an approved verb, full comment-based help,
  `-WhatIf` when it changes state, and an `[OutputType()]` when it returns
  anything.
- Tests use `TaffarelJr.TestKit`, not Pester blocks, and every case marks
  `# Arrange`, `# Act` and `# Assert`. Run only the module you changed:
  `pwsh -NoProfile -File test/Invoke-Tests.ps1 -Module <Name>` (the unit
  tests, no reports); add `-Integration` for the real-tool files and
  `-Coverage` for the reports.
- No token, password, account login, machine name or local path in any file,
  test, commit or issue. Tests use fake values.
- Pull requests are opened as drafts, commits follow Conventional Commits, and
  only the owner marks a pull request ready and merges it.

## More

The detailed rules are the skills in `.claude/skills/`: `module-structure`,
`public-function-contract`, `module-tests`, `module-secrets`,
`wrapping-native-tools`, `module-review`, `repo-workflow` and
`publishing-modules`. Each is plain Markdown; read the one for your task.
