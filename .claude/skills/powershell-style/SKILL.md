---
name: powershell-style
description: >-
  General PowerShell language conventions for this repo, ported from
  .github's instructions and adapted for a multi-module Gallery repo:
  array-return safety, #Requires/StrictMode, approved verbs, comment-based
  help, using-namespace, native-command argument arrays, and other gotchas
  that already cost real debugging time once. Use when writing or reviewing
  any .ps1/.psm1 file in this repo.
when_to_use: >-
  Trigger phrases: write a function, review this script, why did this
  return null, PSScriptAnalyzer warning, approved verb, comment-based help,
  is this PowerShell idiomatic, using namespace.
allowed-tools: Read Edit Write Glob Grep Bash
---

# PowerShell style

Module-layout and naming rules live in the `module-structure` skill; testing
rules live in `module-tests`. This one is everything else: the language and
style rules that apply to any `.ps1`/`.psm1` file in this repo.

- A file that can be run or imported standalone - a module's root `.psm1`,
  a manifest, or a test file invoked via `pwsh -File` - opens with
  `#Requires -Version 7.0`. A `Public/`/`Private/` file only ever reached by
  the root `.psm1` dot-sourcing it does not need its own; it is never run
  any other way. If comment-based help follows a `#Requires` line, leave a
  **blank line** between them - help adjacent to another comment is
  ignored, which silently breaks `-?`.
- Add `using namespace <Namespace>` at the top of a file - before anything
  else except `#Requires` and comments - instead of writing a
  fully-qualified type name repeatedly: `using namespace
  System.Collections.Generic` then `[List[string]]`, not
  `[System.Collections.Generic.List[string]]`. Only add it to a file that
  actually references such a type; an unused `using` is noise. Types with a
  built-in PowerShell accelerator (`[Math]`, `[Console]`, `[regex]`, and
  the like) never need one.
- Set `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
  in every module's root `.psm1`. Module scope does not inherit the
  caller's preference. Without the second line, a failing cmdlet is
  non-terminating, and the next line reports a success that never happened.
- Name functions `Verb-Noun` using an approved verb (`Get-Verb`). Skip
  decorative prefixes; the noun should carry the meaning. (See
  `module-structure` for the `TaffarelJr.<Name>` module-naming convention -
  that's about the module, not the function.)
- Give every function comment-based help: `.SYNOPSIS` always, then
  `.DESCRIPTION` and `.PARAMETER` only where they add something. Add
  `.EXAMPLE` only where the call isn't obvious.
- Phrase `.SYNOPSIS` as a third-person verb phrase, matching what
  `Get-Help` shows for a built-in cmdlet: "Returns the...", "Writes the...".
  Never a bare noun phrase.
- A module that wants to expose a shared default value to its own
  functions *and* to a caller - not just an internal constant - declares it
  with `New-Variable -Option Constant -Scope Script` in the root `.psm1`
  and exports it via `Export-ModuleMember -Variable`. `Option Constant`
  means neither the module nor a caller can reassign it by accident.
- **One command per statement.** Don't chain a pipeline across continuation
  lines: assign the first command's result to a variable, then filter or
  sort it in the next statement. Hoist a long argument array into a
  variable too.

  Exception: a single query - filter, project, or aggregate in one coherent
  pipeline, wrapped on its own `|` characters and assigned or returned as
  one expression - reads fine at two or three stages. The rule targets
  disguising several DIFFERENT operations as one statement, not a pipeline
  that genuinely is one.
- When a call is too long for one line, break at parameter boundaries and
  put each parameter on its own continuation line.
- Pass arguments to native commands as an explicit array -
  `& git @('-C', $path, 'status')`. Loose tokens such as `-C` bind as
  PowerShell parameters instead, silently and without an error.
- After deliberately tolerating a failed native command, reset
  `$global:LASTEXITCODE` so a later check doesn't see a phantom failure.
- **git writes progress and status to stderr even when it succeeds**, which
  PowerShell surfaces as an error and which aborts the rest of a compound
  command. Run git steps as separate statements, and judge them by
  `$LASTEXITCODE`.
- **`(?m)$` does not match before a CRLF line ending** - the `\r` is in the
  way. Prefer `[^\r\n]` and `[ \t]` over `.` and `\s`, and `\r?$` when an
  anchor is genuinely needed. A bare `.` matches `\r`, so a careless
  replace quietly converts the file to LF.
- **`Split-Path -Parent` returns a backslash path.** Normalize it with
  `-replace '\\', '/'` before joining it to a forward-slash relative path,
  or `..` resolution eats the whole prefix instead of one segment.
- Section breaks in a longer file are three lines - a rule, the title, a
  rule - followed by a blank line.
- Use `-LiteralPath` for a filesystem cmdlet call on a variable path, never
  `-Path` - a path containing a wildcard character shouldn't be treated as
  one.
- Prefer `[Parameter(Mandatory)]` over `[ValidateNotNullOrEmpty()]` for a
  required parameter; Mandatory already rejects `$null` and an empty
  string. Add `[ValidatePattern('\S')]` only to also reject whitespace, and
  `[AllowEmptyString()]` only when blank is itself a legitimate value.
- There is no `Write-Error` helper for a genuine failure - a failure is a
  `throw`, rendered by the caller's own error handling. `Write-Failure` and
  `Write-Warn` in `TaffarelJr.ConsoleOutput` are a different thing
  entirely: they print a status line for display, and carry no failure
  semantics of their own - calling one never stops anything or sets
  `$LASTEXITCODE`.
- **When a function must always return an array, even one element, even
  empty, return it with a leading comma** (`return , $result`). A caller
  of such a function must never wrap the call in `@()` - that nests the
  array instead of leaving it flat. This is the single most common
  PowerShell footgun in this codebase's own history - a function that
  looks like it returns a list quietly unwraps to a scalar (or `$null`)
  the moment it has exactly one element or zero, and every caller written
  against the "it's always an array" assumption breaks silently.
- **Put `$null` on the left of `-eq`/`-ne`.** `$value -eq $null` runs the
  comparison backwards when `$value` is an array: PowerShell treats it as
  a filter over the array's elements, not a single boolean check of the
  whole thing, so `@($null, 1) -eq $null` returns a truthy one-element
  array instead of the `$false` a scalar-minded reader expects.
  `$null -eq $value` can't do this - `$null` is never an array - so it is
  always the correct, unsurprising comparison regardless of what
  `$value` turns out to hold. The same shape of bug applies to
  `Assert-Equal`-style helpers: comparing two arrays with a bare `-eq`
  silently never matches, even when they hold the same elements in the
  same order - compare array values element-by-element instead (for
  example with `Compare-Object -SyncWindow 0`).
- Write `[PSCustomObject]` in PascalCase, not `[pscustomobject]`. List
  each property of a `[PSCustomObject]` or a hashtable on its own line
  once it has more than one entry, so the names line up and read like a
  small table:

  ```powershell
  return [PSCustomObject]@{
      FilesEdited  = $content.Edited
      PathsRenamed = $names.Renamed
  }
  ```

  not `[pscustomobject]@{ FilesEdited = $content.Edited; PathsRenamed =
  $names.Renamed }`. A single-entry or empty literal can stay on one
  line - there is nothing to line up. A plain array of simple literal
  values (`@('.git', 'bin', 'obj')`) is about length, not naming; wrap it
  for readability without forcing one bare value per line.
- Spread `if`/`elseif`/`else` and `try`/`catch`/`finally` across lines -
  the condition (or `try`) and its opening brace on one line, the body
  indented beneath it, the closing brace alone on its own line:

  ```powershell
  if ($ExitCode -eq 0) {
      return
  }
  ```

  not `if ($ExitCode -eq 0) { return }`. The one exception is a short,
  single-expression value assignment using `if`/`else` as an expression,
  which can stay compact on one line: `$body = if ($cond) { $a } else
  { $b }`. The moment either branch needs more than a bare expression, or
  the whole thing stops fitting on one line, expand it fully like any
  other `if`. Test files relax this - see `module-tests` - a test case
  already packs several short, similar lines together on purpose.
- Give each parameter attribute its own line - `[Parameter(...)]`,
  `[ValidatePattern(...)]`, `[AllowEmptyString()]`, and the rest each
  stacked on their own line, with only the type and the `$Name` sharing
  a line:

  ```powershell
  [Parameter(Mandatory)]
  [ValidatePattern('\S')]
  [string]$From,
  ```

  not `[Parameter(Mandatory)] [ValidatePattern('\S')] [string]$From`.
