# TaffarelJr.TestRunner

Runs the test files written with [TaffarelJr.TestKit][testkit]:
every `*.Tests.ps1` under one or more folders, several at a time,
each in a process of its own - on its own,
or under a Pester coverage wrapper on request -
and reports pass/fail/crashed per file plus a run summary.
A test file is a plain script that ends with `exit (Complete-TestRun)`;
a file that does not print TestKit's tally line -
a plain Pester file, or a script that ends with `exit 0` -
is reported as crashed.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.TestRunner
```

Requires PowerShell 7.4 or later.

## Usage

A test file, `test/Get-Thing.Tests.ps1`:

```powershell
Import-Module TaffarelJr.TestKit
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'Thing' 'Thing.psd1')

Assert-Equal -Expected 4 -Actual (Get-Thing -Count 4) `
    -Message 'Returns the count it was asked for'

exit (Complete-TestRun)
```

And the run:

```powershell
Import-Module TaffarelJr.TestRunner

$run = Invoke-TestRun -Path 'test' -SourceRoot 'src'
exit $run.ExitCode
```

Each file runs as `pwsh -File` would run it, and nothing else happens:
no Pester is loaded and no report is written.
`Invoke-TestRun` sets the console's encoding to UTF-8
for the length of the run itself,
so a caller never declares that as a prerequisite of its own.

Coverage is on request:

```powershell
$run = Invoke-TestRun -Path 'test' -SourceRoot 'src' -Coverage `
    -OutputPath 'test/coverage' -ResultsPath 'test/results'
exit $run.ExitCode
```

`-Coverage` runs every file under Pester's coverage tracer,
which writes a Cobertura report and a JUnit result for each one.
Setting the tracer up and writing its reports takes seconds a file,
so it is paid for only when the reports are wanted.
It is also the only mode that needs Pester:
`Invoke-TestRun` then makes sure Pester 5.3.0 or later is installed -
installing it without asking, for the current user,
when it is missing or older.
When the test tree mirrors the source tree,
`test/Thing/...` for `src/Thing`,
each file is measured over its own `src/Thing` folder alone,
so a run over every module does not measure every module for every file.

`-Exclude` leaves files out by name.
Each pattern is matched, without regard to case,
against the file name without its `.Tests.ps1` suffix,
in the same vocabulary as `-Filter` - `*` and `?` only -
so `-Exclude '*.Live', '*.Contract'` keeps out
the files that need a real tool.

Narrow `-Path` to a subfolder to run only that part of the tree -
keep `-TestRoot` at the real root so display names stay full,
and every test file has to be under it.
That's the shape a CI job scoped to one module takes.
`-Path` also accepts several folders at once,
as an array or as one comma-joined value
(a folder whose own name has a comma in it stays whole).

## Good to know

- A test file ends by exiting with its own result,
  `exit (Complete-TestRun)` with TestKit.
  A file with no `exit` statement at all is not run and counts as crashed.
  A file that does not parse is not run either: the parser's errors are
  shown, each with its line, and the file counts as crashed.
  A file that ends without reaching its `exit` counts as crashed too -
  with `-Coverage`, unless a native command it ran left an exit code behind,
  which is then taken as the file's own, and its tally decides.
- A file fails when it exits non-zero, crashes, runs past `-TimeoutSeconds`,
  or reports a failed case - whatever its exit code says.
  A file whose tally counts no case at all fails too, unless it said why:
  a file that skipped itself (`exit (Skip-TestRun -Reason ...)`) shows its
  reason and is counted apart in the summary, and a file whose checks run
  by other means (`exit (Complete-TestRun -AllowEmpty)`) passes with a note
  saying so.
  A file that cannot even be started is reported as not started,
  with the reason, not left out of the run.
- A file runs in its own process,
  and without `-Coverage` the file is that process's script scope,
  exactly as when it is run on its own.
  With `-Coverage` it runs in a scope of its own
  that starts with strict mode off and `$ErrorActionPreference` at `Continue`,
  and everything it writes - the pipeline, errors, warnings,
  and host output - is captured in the order it was written.
  Some things then differ from a run on its own,
  where the file is the global scope:
  - The file's scope sits below the wrapper's and Pester's,
    so it can read their variables.
  - Functions of the modules it imports run with `$ErrorActionPreference`
    at `Stop`, the wrapper's own - what a file that sets `Stop` for itself
    gives them when it runs on its own.
  - Information messages (`Write-Information`) are shown
    whatever `$InformationPreference` says.
  - Each output object is formatted on its own,
    so two objects of one type print as two tables, each with its header.
- `-TimeoutSeconds` stops a file that never finishes and counts it as crashed,
  along with any process the file started that still holds its output open.
  By default there is no limit, and a file that never ends
  never lets the run end.
- By default as many files run at once as the machine has processors;
  `-ThrottleLimit` sets another number.
- Every file runs in the deepest folder holding all of `-SourceRoot`,
  wherever the run was started, so coverage reports name the same paths
  every time - or, for roots that share no folder,
  in this process's working directory.
  Under `-Coverage`, a file measured over one module's folder, as above,
  starts in that folder.
  Pester 6 makes the paths relative to the git repository holding
  that folder, or to the folder itself when there is none;
  Pester 5 makes them relative to the deepest folder
  holding every file it measured.
- With `-Coverage`, every file runs under the Pester
  the calling session has loaded - even one imported by its path -
  or, with none loaded, the Pester 5.3.0 or later
  that `Import-Module` finds by name.
- The run's exit code is the number of failed files,
  held to what an exit status can carry, or 1 when no file matched.
- With `-Coverage`, reports are overwritten file by file;
  reports of test files that no longer exist are left where they are.
- With `-Verbose`, `Invoke-TestRun` and `Invoke-TestFileProcess`
  show the command line of each test file's process before it starts.

A test file imports the thing it's testing itself -
`Import-LocalModule -Path 'src/TheModule'` imports whatever's
directly in that folder without the file needing to know which shape it
turns out to be: the `.psd1` or `.psm1` named like the folder, else a lone
`.psd1`, else a lone `.psm1`, never a loose `.ps1`. A lone `.psd1` is taken
as the module even when it is only a settings file, so a module that shares
its folder with another `.psd1` is named like the folder. It's deliberately
not recursive and never a whole tree at once - only the one folder a caller
actually needs.

With `-Coverage`, `-WrapperPath` defaults to this module's own coverage
wrapper - override it only to run a file under a different Pester
configuration. A wrapper decides how a single file actually runs under
coverage and must accept `-TestFile`, `-SourceRoot`, `-OutputPath`,
and `-ResultPath`, exiting with the test file's own exit code.
The path of the Pester to use, when the caller has one loaded,
is in the `TESTRUNNER_PESTER_PATH` environment variable.
Without `-Coverage` the wrapper is not used, and a file never has the variable.

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
as in `RuntimeException,Invoke-TestRun`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

A failing test file is not an error but a result:
`Invoke-TestRun` counts it, and its exit code is the number of failed files.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified (`TaffarelJr.TestRunner\<Command>`)
or import the module with `-Prefix` to keep them apart.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
[testkit]: https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
