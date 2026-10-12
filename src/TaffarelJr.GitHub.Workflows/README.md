# TaffarelJr.GitHub.Workflows

Runs and manages GitHub Actions through the GitHub CLI (gh):
dispatch workflows and wait for their runs, manage workflows and runs,
download artifacts, and clear Actions caches.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Workflows
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh:
`Get-GitHubWorkflowRun` and `Wait-GitHubWorkflowRun` need 2.50,
`-All` on `Get-GitHubWorkflowRun` 2.52,
`-SucceedOnNoCaches` on `Remove-GitHubCache` 2.68,
`-Force` on `Stop-GitHubWorkflowRun` 2.78,
`-Ref` on `Remove-GitHubCache` 2.86,
and the run `Start-GitHubWorkflow` returns 2.87.
An older gh fails on them with its own message,
except that `Start-GitHubWorkflow` then returns no run.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Workflows

$listing = @{ Workflow = 'draft-release.yml'; Trigger = 'workflow_dispatch'; Branch = 'main' }
$before = @(Get-GitHubWorkflowRun -List @listing -Limit 1)
$dispatch = Start-GitHubWorkflow -Workflow 'draft-release.yml' -Ref 'main'
$runId = $dispatch.DatabaseId
if ($null -eq $runId) {
    $runId = Wait-GitHubWorkflowRunStart -Workflow 'draft-release.yml' -Before $before -Ref 'main'
}

$run = Wait-GitHubWorkflowRun -RunId $runId
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- `Start-GitHubWorkflow` returns the new run's `Url` and `DatabaseId`
  from gh 2.87 on. An older gh, or a GitHub that does not report the run,
  leaves both `$null`; `Wait-GitHubWorkflowRunStart` then finds the run
  by polling for one newer than `-Before`,
  which needs `-Before` listed as broadly as that poll:
  `workflow_dispatch` runs on the same ref, as above.
- A workflow piped in from `Get-GitHubWorkflow` is found by its `Id`,
  a run from `Get-GitHubWorkflowRun` by its `DatabaseId`, and a cache from
  `Get-GitHubCache` by its `Id`.
  A run parameter is `-RunId`, never `-Id`,
  so a workflow or cache object cannot pass for a run;
  an object whose `Url` is not that run's - a job, a release - is refused,
  and so is an object without a `Key` piped in as a cache.
  A piped job is refused with advice:
  pipe its run instead, or give the job's id to `-Job`.
- A piped object is acted on in the repository it came from -
  its `Repository`, which the `Get-` functions always attach
  (`$null` for the current directory's), else the repository in a run's `Url`;
  a `-Repository` that names another repository throws.
  The attached `Repository` is written `OWNER/REPO`
  (`HOST/OWNER/REPO` off github.com), however the repository was named,
  so `Where-Object Repository -EQ 'OWNER/REPO'` finds every object of it.
  `Wait-GitHubWorkflowRunStart` reads a workflow object and its `-Before`
  runs the same way, so it polls where `Start-GitHubWorkflow` dispatched.
- `-Repository $null` throws; only leaving `-Repository` out means
  the current directory's repository. A filter given blank,
  such as `-Branch ''`, throws too, rather than widening a listing.
- `Start-GitHubWorkflow` sends each input as one string:
  a list, a hashtable, or another object is refused.
  The inputs go to gh as one JSON object on its standard input,
  so they are not in `-Verbose` output or in error messages,
  but GitHub shows a dispatch's inputs in the run,
  so a secret does not belong in an input.
- Both waits throw a `TimeoutException` when time runs out,
  naming what they still waited for.
  A failed read ends either wait at once, with gh's message -
  a run or workflow that does not exist, a 403, a rate limit alike -
  so the timeout bounds a wait only while its reads succeed.
- `Remove-GitHubCache` and `Remove-GitHubWorkflowRun` delete without asking:
  nothing asks for confirmation unless you pass `-Confirm`.
  A key deletes every cache with that key, on every ref.
- `Save-GitHubWorkflowRunArtifact` needs a run, a name, or a pattern;
  `-Pattern '*'` downloads every artifact on purpose.

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
as in `RuntimeException,Invoke-GitHubCommand,Stop-GitHubWorkflowRun`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name as one here.
The last one imported wins,
so call it module-qualified,
as in `TaffarelJr.GitHub.Workflows\Get-GitHubWorkflowRun`,
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
