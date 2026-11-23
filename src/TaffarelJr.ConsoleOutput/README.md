# TaffarelJr.ConsoleOutput

Indent-aware console output for PowerShell scripts:
boxed banners, headers,
a progress line that is opened and later ended with how it went,
name and value lines and lists of them,
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

Each `Show-*` command but the two field commands
takes its text as the first argument or from the pipeline.
`Show-Detail` has no marker:
it sits three spaces in, under the text of the line above it.

`Show-Field` prints a name and its value on one line, in gray.
`-Budget` is the width of the name column:
the values of the fields that share it start in the same column.
A name wider than the budget is not cut,
and its value starts one space after the colon.
The entries of a dictionary and the properties of an object
(`$object.PSObject.Properties`) carry a name and a value,
so they pipe straight in:

```powershell
Show-Field 'Branch' 'main'

$fields = [ordered]@{
    Branch       = 'main'
    Commit       = 'a1b2c3d'
    'Remote URL' = 'origin'
}
$fields.GetEnumerator() | Show-Field -Budget 10

$object = [PSCustomObject]@{ Name = 'tool'; Version = '1.2' }
$object.PSObject.Properties | Show-Field -Budget 7

# Branch: main
# Branch:     main
# Commit:     a1b2c3d
# Remote URL: origin
# Name:    tool
# Version: 1.2
```

A value is shown as the text PowerShell makes of it:
an array is its elements separated by spaces,
a hashtable is its type name, and `$null` is nothing.
A field with no value ends at its colon.

`Show-FieldList` prints a list, a dictionary, or an object as fields,
and fits the name column to the longest name itself.
A list is its elements, named by position from 0;
a dictionary is its entries, named by key;
an object is its properties.
A list, dictionary, or custom object inside another
is printed as its name alone with its own fields one level in,
lined up in a column of their own:

```powershell
$package = [ordered]@{
    Name   = 'tool'
    Paths  = @('src', 'test')
    Author = [ordered]@{ Name = 'Ada'; Role = 'maintainer' }
}
Show-FieldList $package

'one', 'two' | Show-FieldList -Budget 4

# Name: tool
# Paths:
#   0: src
#   1: test
# Author:
#   Name: Ada
#   Role: maintainer
# 0:    one
# 1:    two
```

`-Budget` fixes the column of the top level only,
and `-Depth` says how many levels inside it are opened:
the default is 3, and a value below that is shown as text,
which also stops a structure that contains itself.
A hashtable keeps no order, so its entries are sorted by name;
an ordered dictionary or a generic dictionary keeps its own.

A single value, such as a string, a number, or `$null`,
is printed as a list of one, at position `0:`;
`Show-Field` prints it under a name of your own.
Only a custom object is opened, as `Select-Object` returns it;
any other object, such as a file item or a date, is text.
To list the properties of one, select them first:
`Get-Item ./README.md | Select-Object Name, Length | Show-FieldList`
prints position `0:` with those properties under it.

What the command receives decides how it reads it.
A dictionary passed as an argument is the list of its entries,
but piped, it is one element, shown at position `0:` with its entries under it;
pipe `$dictionary.GetEnumerator()` to list the entries.
Likewise an object with a `Name` and a `Value` property
shows as `tool: 1.2` when piped and as its two properties when passed.
Any other value, passed or piped in, is an element of a list,
named by position.
Nothing is printed until the input ends,
because the column depends on the longest name,
and nothing is printed at all if what feeds the pipeline throws.

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

`Show-Doing` announces work on a line it leaves open,
and `Show-Done` ends that line with how it went:
"done" in green by default,
"already done" in dark gray with `-Skip`,
and yellow with `-Warn`, for an outcome that is neither,
such as "would create".
Either takes its own wording.
`Invoke-Doing` does both around a script block:

```powershell
Show-Doing 'Restoring packages'
Show-Done -Skip

Show-Doing 'Installing'
Show-Done 'installed 3 packages'

Invoke-Doing 'Compiling' { Start-Sleep -Milliseconds 1 }

# ▶ Restoring packages ... already done
# ▶ Installing ... installed 3 packages
# ▶ Compiling ... done
```

`Invoke-Doing` ends the line however the block ends:
"done" when it finishes,
"failed" in red when it throws, with the error still reaching the caller,
and "stopped" in yellow when it is left with `break` or `continue`.
What the block writes is passed on once the line has ended.
With no line open, `Show-Done` writes its outcome on a line of its own,
as `Show-Success`, `Show-Skip` or `Show-Warning` would.

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
  A field's value is the same, in `Show-Field` and `Show-FieldList`:
  its later lines start at the left edge.
- `Show-Doing` leaves a line open, and every other command in this module
  that writes a line ends it first, so nothing from this module runs on to the
  end of it.
  Output from anywhere else does:
  the built-in `Write-Warning` and `Write-Error`, a native command,
  and anything that reaches the host through the pipeline.
  End the line with `Show-Done` before any of those.
- Capturing the information stream (`6>&1`, `*>&1`)
  turns the open line and its outcome into separate records,
  and `6>$null` hides the line while `Show-Done` still tries to end it.
- `Show-Header` and `Show-Banner` give every line of their text the indent.
  They do not wrap text:
  a line wider than the console widens the rules or the box past it.
  The width is the window's,
  or 80 columns when standard output is redirected or there is no window.
- `Show-Header`, `Show-Banner`, `Show-Field`, and `Show-FieldList`
  measure width in characters,
  so wide characters, emoji, and color codes in the text
  throw the alignment off:
  a banner's right border moves out of line,
  a header's rules come out wider than the text shows,
  and a field's value drifts out of its column.
- `Invoke-Indented` puts the indent back even when its block throws.
  A script that fails between a `Push-Indent` and its `Pop-Indent`
  leaves its level behind for the rest of the session;
  `Reset-Indent` takes every level off at once.
- `Invoke-Indented` runs its block in the caller's scope,
  as `ForEach-Object` does,
  so a variable the block assigns is the caller's variable.
- `Pop-Indent` with nothing to pop writes a warning;
  `-WarningAction SilentlyContinue` hides it.
- The indent and the open line are kept per PowerShell runspace.
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
