# TaffarelJr.Tally

A generic named-counter utility for PowerShell scripts:
add to a counter by name, read it back, clear it,
render every counter as one joined string for a log line or job summary,
and parse that same string back into counts.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.Tally
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.Tally

# Counters outlive a re-import, so start from zero
Clear-Tally

Add-Tally -Name 'passed'
Add-Tally -Name 'failed' -Amount 2
Format-Tally
# 1 passed - 2 failed

Read-Tally -Text '1 passed - 2 failed'
# Name   Count
# ----   -----
# passed     1
# failed     2

# -Key isolates a set of counters under their own namespace,
# so two callers can both use a name like "passed"
# without adding to the same running count
Clear-Tally -Key 'MyModule'
Add-Tally -Name 'passed' -Key 'MyModule'
Format-Tally -Key 'MyModule'
# 1 passed

# Names can be piped in, to count what flows past
Clear-Tally -Key 'Extensions'
'txt', 'md', 'txt' | Add-Tally -Key 'Extensions'
Format-Tally -Key 'Extensions'
# 2 txt - 1 md

# A piped object adds its own Count,
# so a line printed by another process merges in whole
Clear-Tally -Key 'Merged'
Read-Tally -Text '5 passed - 2 failed' | Add-Tally -Key 'Merged'
Format-Tally -Key 'Merged'
# 5 passed - 2 failed
```

`Add-Tally` reads a piped object's `Count`;
`Format-Tally` does not.
It shows the module's own counter for each name it is given,
so `Read-Tally '5 passed' | Format-Tally` prints `0 passed`.
To show counts read from text, merge them with `Read-Tally | Add-Tally` first.

Counters are shared by the whole process and safe to add to from any runspace.
They last as long as the process does:
removing or re-importing the module, or importing it in a new runspace,
keeps every count.
Only `Clear-Tally` resets them,
so a script that needs to start from zero starts with `Clear-Tally`
(or `Clear-Tally -Key` with its own key).
Code meant for others to use should always pass `-Key`.

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

A failing record in a pipeline stops the pipeline,
and the records before it were processed;
`Format-Tally` gathers its names first and returns its line at the end,
so a failing record means no line at all.
A piped value that fails to bind, such as `$null` for a name,
is the exception: that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Add-Tally`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.Tally\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
