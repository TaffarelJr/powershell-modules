# TaffarelJr.TestRunner

Runs every `*.Tests.ps1` under a folder,
each in its own process under a caller-supplied coverage wrapper,
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
    -OutputPath 'test/coverage' -WrapperPath './Invoke-TestFile.ps1'
exit $run.ExitCode
```

`-WrapperPath` is a script this module doesn't provide -
it decides how a single file actually runs under coverage
(Pester, or anything else),
and must accept `-TestFile`, `-SourceRoot`, and `-OutputPath`,
exiting with the test file's own exit code.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
