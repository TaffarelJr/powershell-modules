# TaffarelJr.TestKit

A small test kit for PowerShell test files that are plain scripts,
not Pester blocks.
A test file imports the module, makes its assertions,
and ends with `exit (Complete-TestRun)`,
so the file reports through its exit code;
`TaffarelJr.TestRunner` runs such files.
The kit is not Pester and needs none.

It provides strict `Assert-That`, `Assert-Equal`, and `Assert-Throws`,
a per-file pass/fail tally shared across runspaces,
`Skip-TestRun` for a file that is not running here,
`Get-HostOutput` and `Get-WarningOutput`
for capturing what a script block printed,
`Get-WhatIfOutput` for the `What if:` lines a `-WhatIf` call printed,
kept apart from what it returned,
and `Use-SplitLocation` for running code with PowerShell and the process
in different folders, which is when a relative path goes to the wrong file.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.TestKit
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.TestKit

Assert-Equal -Expected 4 -Actual (2 + 2) -Message '2 + 2 is 4'
Assert-Throws -ScriptBlock { throw 'boom' } -MessageLike 'b*' -Message 'it throws'
exit (Complete-TestRun)
```

`Assert-Equal` is strict: `'Abc'` is not `'abc'`, a string with a stray
byte order mark is not the same string without it, `0` is not `''`,
`$null` equals only `$null`, and dictionary keys and object property names
compare case-sensitively.
Numbers of the built-in integer and floating-point types, and decimal,
compare by value, exactly;
any other numeric type compares by type and value.
A decimal matches a floating-point number only when it is the nearest one to it.

`Assert-That` takes only `$true` or `$false`, as a comparison gives;
a number or a string is an error, not a condition,
so write the comparison out (`$items.Count -gt 0`).

`Assert-Throws` looks at the exception and every inner exception under it;
give it `-MessageLike` or `-ExceptionType`, since with neither a typo in a
command name also passes.

A file with no assertions fails, unless it ends with
`exit (Skip-TestRun -Reason ...)` (not running here) or
`exit (Complete-TestRun -AllowEmpty)` (it checks by throwing instead).
Like Skip-TestRun's `skipped - <reason>` line, an empty file accepted by
`-AllowEmpty` prints `allowed empty - checks run by other means` before its
tally line, so a runner can tell either one from a file that crashed.
Each of them empties the tally, so files run one after another in one
session count only their own cases.

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

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Skip-TestRun`;
the message is what says what failed.

A failed assertion is not an error:
`Assert-That`, `Assert-Equal` and `Assert-Throws` count it and print it,
and `Complete-TestRun` turns the count into the file's exit code.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.TestKit\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
