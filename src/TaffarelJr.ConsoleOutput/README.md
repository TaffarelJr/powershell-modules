# TaffarelJr.ConsoleOutput

Indent-aware console status lines for PowerShell scripts:
detail, failure, info, skip, success, and warning lines,
each with its own emoji marker and color,
printed at an indent you add and take off levels of,
or run a script block one level in.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ConsoleOutput
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.ConsoleOutput

Show-Info 'Building'
Invoke-Indented {
    Show-Success 'Compiled'
    Show-Skip 'Packages are already restored'
    Show-Warning 'The cache is stale'
    Show-Failure 'Tests failed'
    Show-Detail 'See test.log for the output.'
}

# ℹ️  Building
#   ✅ Compiled
#   ⏭️  Packages are already restored
#   ⚠️  The cache is stale
#   ❌ Tests failed
#      See test.log for the output.

# Push-Indent and Pop-Indent do the same without a block
Push-Indent
Show-Info 'one level in'
Pop-Indent
```

Each `Show-*` command takes its text as the first argument or from the pipeline.
`Show-Detail` has no marker:
it sits three spaces in, under the text of the line above it.

`Get-Indent` returns the indent as spaces,
ready to put in front of a line of your own,
and `Get-IndentSize` returns the same indent as a number.
`$DefaultIndentWidth` is the width of a level when `-Width` is not given.

## Good to know

- Every `Show-*` command uses `Write-Host`, so `6>$null` silences it,
  and nothing it prints reaches the pipeline.
- `Show-Warning` prints to the host;
  it does not write to the warning stream,
  so `$WarningPreference` and `-WarningAction` do not apply to it.
  Use the built-in `Write-Warning` for a warning that should honor them.
- The markers need a UTF-8 output encoding:
  a Windows host whose `[Console]::OutputEncoding` is not UTF-8
  prints question marks in their place.
- A message with line breaks has its indent and marker on the first line only.
- `Invoke-Indented` puts the indent back even when its block throws.
  A script that fails between a `Push-Indent` and its `Pop-Indent`
  leaves its level behind for the rest of the session;
  `Reset-Indent` takes every level off at once.
- `Invoke-Indented` runs its block in the caller's scope,
  as `ForEach-Object` does,
  so a variable the block assigns is the caller's variable.
- `Pop-Indent` with nothing to pop writes a warning;
  `-WarningAction SilentlyContinue` hides it.
- The indent is kept per PowerShell runspace.
- The exported `$DefaultIndentWidth` is read-only, so remove the module with
  `Remove-Module -Force`: without it the removal fails part way and leaves the
  module listed with its commands gone.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.ConsoleOutput\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
