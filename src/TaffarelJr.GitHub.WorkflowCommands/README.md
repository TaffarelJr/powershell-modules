# TaffarelJr.GitHub.WorkflowCommands

PowerShell commands for the steps of a GitHub Actions workflow:
annotate and group the log, hide secrets,
and pass outputs, environment variables, PATH changes, summaries,
and saved state to later steps.
They talk to the runner directly and need no GitHub CLI,
so they work in any Actions job regardless of what else is installed.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.WorkflowCommands
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.WorkflowCommands

Set-GitHubActionsOutput -Name 'version' -Value '1.2.3'
Write-GitHubActionsWarning -Message 'Falling back to the cached value' -File 'build.ps1' -Line 42
Invoke-GitHubActionsLogGroup 'Restoring packages' {
    dotnet restore
}
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Workflow commands are written as UTF-8 straight to the process's
  standard output, the only place the runner reads them.
  They do not go through PowerShell's streams,
  so `-InformationAction Ignore`, `6>$null`, or capturing `*>&1`
  cannot swallow one - not even an `add-mask`.
  For the same reason, `Start-Transcript` does not record them.
- That holds in the step's own console process,
  a thread job or `ForEach-Object -Parallel` block in it included;
  those put a line break in front, so a command always starts a line,
  at the cost of an occasional blank one.
  A background job or a remote session - and a thread job
  or `-Parallel` block inside one - sends them through `Write-Host` instead,
  since there the process's standard output carries the session itself;
  the parent shows them after the job's output.
  So mask a value in the step's own process before such a job prints it.
  A `[powershell]` runspace created inside such a job
  has to pass its own information stream on, or its commands stay there.
- The commands are for a step's script.
  Elsewhere - an editor's integrated console, a notebook kernel -
  a thread job or `-Parallel` block still writes them
  to that process's standard output.
- The runner recognizes a command only at the start of a line:
  end a partial line, such as one from `Write-Host -NoNewline`,
  with a newline before writing a command, or the command is shown as text.
- A name for an output, an environment variable, or saved state cannot hold a
  line break, `=`, or `<<`, or end in `<`: the runner reads those files line
  by line, and would end the name early and read the rest as entries of its
  own. Nor can it hold a control character other than a tab.
  Such a name throws.
  A value may hold anything, line breaks included, but a NUL character:
  an environment variable cannot hold one, so it throws.
- The runner creates its files before each step,
  so a `GITHUB_*` variable naming a file that is not there throws
  rather than creating one the runner never reads.
  A relative path in one is taken from PowerShell's location.
- `Set-GitHubActionsEnvironmentVariable` refuses `NODE_OPTIONS`,
  which the runner refuses, and the names the runner sets for every step
  over the value written: `GITHUB_ACTIONS`, the `GITHUB_` names of the
  github context (`GITHUB_SHA`, `GITHUB_OUTPUT`), and the `RUNNER_` names of
  the runner context (`RUNNER_OS`, `RUNNER_TEMP`) - in any casing on Windows.
  Any other name, `GITHUB_TOKEN` or `CI` among them, reaches later steps.
- `Add-GitHubActionsPath` writes the directory as a full path,
  so every later step means the same place.
- `Hide-GitHubActionsValue` masks any non-blank value, however short -
  masking `1` blots out every 1 in the log - and ignores a blank one,
  so an optional secret can be passed whether it is set or not.
- The annotation functions only annotate; they do not fail the step.
  Throw, or exit non-zero, to do that.
  A position the runner would quietly move or drop,
  such as `-EndLine` without `-Line`, throws.
  `Select-String TODO *.ps1 | Write-GitHubActionsWarning`
  marks each match at its file and line.
- Log groups do not nest.
  `Invoke-GitHubActionsLogGroup` ends its group however the block finishes,
  a throw included;
  a throw between `Enter-` and `Exit-GitHubActionsLogGroup` leaves it open.
  An object output inside a group can print after it ends,
  as PowerShell formats it a moment later:
  pipe it to `Out-Host` to keep it in the group.

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
and the records before it were processed.
A piped value that fails to bind, such as `$null`, is the exception:
that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Set-GitHubActionsOutput`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name;
the last one imported wins.
Call a command module-qualified,
such as `TaffarelJr.GitHub.WorkflowCommands\Set-GitHubActionsOutput`,
or import the module with `-Prefix`.

## Not covered

Action inputs (`INPUT_<NAME>`), the debug-logging check (`RUNNER_DEBUG`),
command echoing (`::echo::`), and suspending command processing
(`::stop-commands::`) are left out:
this covers the commands and files a step's own script writes.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
