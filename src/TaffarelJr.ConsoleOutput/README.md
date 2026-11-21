# TaffarelJr.ConsoleOutput

The indent for a PowerShell script's console output:
add and take off levels, get the indent as spaces to print or as a number,
reset it after a failure,
or run a script block one level in
and put the indent back when the block ends, even when it throws.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ConsoleOutput
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.ConsoleOutput

function Write-Line {
    param([string]$Text)
    Write-Host "$(Get-Indent)$Text"
}

Write-Line 'Building'
Invoke-Indented {
    Write-Line 'compiling'
    Invoke-Indented -Width 4 {
        Write-Line 'one file'
    }
}

# Building
#   compiling
#       one file

# Push-Indent and Pop-Indent do the same without a block
Push-Indent
Write-Line 'one level in'
Pop-Indent
```

`Get-Indent` returns the indent as spaces, ready to put in front of a line,
and `Get-IndentSize` returns the same indent as a number.
`$DefaultIndentWidth` is the width of a level when `-Width` is not given.

## Good to know

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
