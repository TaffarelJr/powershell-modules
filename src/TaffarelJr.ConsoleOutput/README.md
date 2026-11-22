# TaffarelJr.ConsoleOutput

Indent-aware console output for PowerShell scripts:
boxed banners, headers,
and status lines (detail, failure, info, skip, success, and warning)
with their own emoji markers and colors,
printed at an indent you add and take off levels of,
or run a script block one level in.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ConsoleOutput
```

Requires PowerShell 7.6 or later.

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

`Show-Header` prints text between two rules,
and `Show-Banner` prints it inside a box, both in cyan:

```powershell
Show-Header 'Build' -Trim
Show-Banner 'BUILD FAILED' -Trim

# ─────
# Build
# ─────
# ┌──────────────┐
# │ BUILD FAILED │
# └──────────────┘
```

Each is set apart by a blank line before and after.
They span the console by default, less the indent,
and `-Trim` shrinks them to fit the text.
A header keeps every line of its text at the left edge,
and a banner centers each line of its text on its own,
with the extra column on the right when it cannot be centered exactly.

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
- The markers and the box-drawing characters need a UTF-8 output encoding:
  a Windows host whose `[Console]::OutputEncoding` is not UTF-8
  prints question marks in their place.
- A message with line breaks has its indent and marker on the first line only.
- `Show-Header` and `Show-Banner` give every line of their text the indent.
  They do not wrap text:
  a line wider than the console widens the rules or the box past it.
  The width is the window's,
  or 80 columns when standard output is redirected or there is no window.
- Both measure width in characters,
  so wide characters, emoji, and color codes in the text
  throw the alignment off:
  a banner's right border moves out of line,
  and a header's rules come out wider than the text shows.
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
