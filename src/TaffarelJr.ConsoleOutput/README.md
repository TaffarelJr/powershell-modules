# TaffarelJr.ConsoleOutput

Indent-aware console status output for PowerShell scripts:
success/skip/warn/failure lines, `Doing`/`Done` progress,
numbered step banners, and word-wrapped, box-drawn headers and banners.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ConsoleOutput
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.ConsoleOutput

Write-Step 'Build'
Write-Doing 'Compiling'
Write-Done
Write-Success 'Build complete'

# Invoke-Doing opens the line, runs the block, and closes the line
# with the last string the block returns ("done" when it returns none)
Invoke-Doing -Text 'Packing' -ScriptBlock {
    Start-Sleep -Seconds 1
    'packed 3 files'
}
```

`Write-Done` ends an open line in green,
in dark gray with `-Skip` ("already done"),
and in yellow with `-Warn`, for an outcome that is neither,
such as "would create".

## Good to know

- Everything is written with `Write-Host`, so `6>$null` silences it.
  Capturing that stream instead (`6>&1`, `*>&1 | Out-File`) turns every
  `Write-Host` call into a line of its own, so a `Write-Doing` line and its
  `Write-Done` outcome land on separate lines.
- The indent-mismatch warnings from `Pop-Indent` and `Invoke-Indented` go to
  the warning stream, not to `Write-Host`.
- `Invoke-Doing` holds back the warnings its block writes
  and writes them after the closed line,
  and a block that throws closes the line with "failed" and is raised again.
  When the caller's `$WhatIfPreference` is on,
  the line is written only after the block has run,
  so the `What if:` lines of the block's own commands do not land on it.
- Only this module's own writers close an open `Write-Doing` line first.
  `Write-Warning`, a native command, or pipeline output runs on to the end of
  it, so finish the line with `Write-Done` before any of those.
- The markers (`▶`, `✅`, `⚠️`, ...) need a UTF-8 output encoding: a Windows
  host whose `[Console]::OutputEncoding` is not UTF-8 prints each one as `?`.
- Headers and banners span the console window.
  When the process's own output goes to a file or a pipe
  (`pwsh -File build.ps1 > build.log`), or there is no window,
  they fit within 80 columns;
  redirecting a PowerShell stream (`*> log.txt`) inside a terminal
  keeps the window's width.
- The indent, the open `Write-Doing` line, and the step count are kept per
  PowerShell runspace. Output from several runspaces at once interleaves.
- A box is sized in characters, not screen columns, so wide characters and
  emoji can push its right border out of line.
  Color codes and hyperlink markup take no room.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Errors

A failing call is a terminating error for that call:
the function stops where it failed,
and `-ErrorAction SilentlyContinue` and `Ignore` neither skip nor hide the error.
It ends the call, not the caller's script,
unless the script sets `$ErrorActionPreference = 'Stop'`
(the `pwsh` shell of GitHub Actions already does)
or catches the error with `try` and `catch`.

A piped value that fails to bind, such as a value that cannot become a string,
is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that value without a word;
the values before it were already written.

Apart from a parameter that fails validation,
the failure to expect is an error raised by the script block
given to `Invoke-Indented` or `Invoke-Doing`.
It comes out as it was raised, with the command added to the end of its
`FullyQualifiedErrorId`,
which names the exception type and the commands it passed through:
`RuntimeException,Invoke-Indented` for a plain `throw`.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.ConsoleOutput\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
