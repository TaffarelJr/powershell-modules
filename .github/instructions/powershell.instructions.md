---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
description: "PowerShell style for this repository's modules, scripts, manifests and tests."
---

# PowerShell in this repository

- Target PowerShell 7.4 only. A module's root `.psm1`, a script and a test file
  open with `#Requires -Version 7.4`; a manifest sets
  `PowerShellVersion = '7.4'` and `CompatiblePSEditions = @('Core')`.
- A root `.psm1` sets `Set-StrictMode -Version Latest` and
  `$ErrorActionPreference = 'Stop'`, dot-sources `Private/` then `Public/`, and
  exports functions by a literal, sorted list. Never export with a wildcard, in
  the `.psm1` or in the manifest.
- Save files as UTF-8 without a BOM, with CRLF line endings.
- Aim for 80 columns and never pass 120. Break a long call at parameter
  boundaries, one per line, or splat a hashtable. One command per statement:
  assign a result, then filter it in the next statement.
- Spread `if`/`else` and `try`/`catch`/`finally` over lines; only a short value
  assignment such as `$x = if ($c) { $a } else { $b }` stays on one line. Test
  files may pack several short, similar lines together.
- Give each parameter attribute its own line, and put `[CmdletBinding()]` on
  its own line above `param`.
- Name functions `Verb-Noun` with an approved verb (`Get-Verb`) and a singular
  noun, with no decorative prefix.
- Write no comments except a non-obvious reason, on the line it explains.
  Tests keep their `# Arrange`, `# Act` and `# Assert` markers.
- Stream results one at a time (`return $results`); never protect an array
  with a leading comma. Callers that need an array wrap the call in `@()`.
- Use `-LiteralPath` for a filesystem cmdlet on a variable path, put `$null`
  on the left of a comparison, and build paths with multi-segment `Join-Path`
  and no drive letters.
- An exported function has full comment-based help with a `.PARAMETER` for
  every parameter, an `[OutputType()]` when it returns anything, and
  `SupportsShouldProcess` when it changes state.
- A native tool runs through the module's helper for it with an argument
  array, never a command string or `Invoke-Expression`; an operand a caller
  supplies may not start with `-`.
- A secret goes on standard input, in the child environment or as a
  `[securestring]`, never as an argument, and every message that could echo it
  hides it. Tests use fake values such as `SENTINEL_SECRET_123`.
- `PSScriptAnalyzerSettings.psd1` (root for `src`, `test/` for the tests) is
  the mechanical rule. Fix a finding at its cause; suppress a rule only where
  it is wrong for that code, after `[CmdletBinding()]`, with a true
  `Justification`.
- Tests use `TaffarelJr.TestKit` (`Assert-Equal`, `Assert-That`,
  `Assert-Throws` with `-MessageLike` or `-ExceptionType`), never Pester's
  `Describe` or `It`, and end with `exit (Complete-TestRun)`.
