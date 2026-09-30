# TaffarelJr.TestRunner

Runs every `*.Tests.ps1` under one or more folders, several at a time,
each in its own process under a Pester coverage wrapper,
and reports pass/fail/crashed per file plus a run summary.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.TestRunner
```

## Usage

```powershell
Import-Module TaffarelJr.TestRunner

$run = Invoke-TestRun -Path 'test' -SourceRoot 'src' `
    -OutputPath 'test/coverage' -ResultsPath 'test/results'
exit $run.ExitCode
```

That's the whole entry point a caller has to write. `Invoke-TestRun` checks
Pester is installed and fixes the console's encoding itself, so a caller
never declares those as prerequisites of its own.

Narrow `-Path` to a subfolder to run only that part of the tree -
keep `-TestRoot` at the real root so display names stay full.
That's the shape a CI job scoped to one module takes.
`-Path` also accepts several folders at once,
as an array or as one comma-joined value.

A test file imports the thing it's testing itself, the same way it always
has - `Import-LocalModule -Path 'src/TheModule'` imports whatever's
directly in that folder, its own `.psd1` manifest if it has one, a bare
`.psm1` otherwise, never a loose `.ps1`, without the file needing to know
which shape it turns out to be. It's deliberately not recursive and never
a whole tree at once - only the one folder a caller actually needs.

`-WrapperPath` defaults to this module's own coverage wrapper -
override it only to run a file under a different Pester configuration.
A wrapper decides how a single file actually runs under coverage
and must accept `-TestFile`, `-SourceRoot`, `-OutputPath`, and `-ResultPath`,
exiting with the test file's own exit code.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
