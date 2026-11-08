# TaffarelJr.GitHub.PullRequests

Works with GitHub pull requests through the GitHub CLI (gh):
create, review, comment on, merge, and close them,
and read their checks and diffs.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.PullRequests
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh:
`Get-GitHubPullRequestCheck` needs 2.50, `-RemoveMilestone` 2.54,
`Update-GitHubPullRequestBranch` 2.53, `-CreateIfNone` 2.68, `-Exclude` 2.88,
and `-Worktree` 2.98.
An older gh fails on them with its own message.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.PullRequests

$notes = Get-Content -LiteralPath './sync-notes.md' -Raw
$open = @(Get-GitHubPullRequest -List -Head 'template-sync' -Repository 'owner/repo')
if ($open.Count -eq 0) {
    New-GitHubPullRequest -Title 'Sync template' -Body $notes `
        -Base 'main' -Head 'template-sync' -Repository 'owner/repo'
}

# preview the merge first, then run it without -WhatIf
Get-GitHubPullRequest -List -Author 'app/dependabot' -Limit 1000 -Property number |
    Merge-GitHubPullRequest -Strategy squash -WhatIf
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Every function that acts on a pull request takes its number, its URL,
  its head branch, or a pull request object, so a listing or a search result
  pipes straight in. `Lock-GitHubPullRequest` and `Unlock-GitHubPullRequest`
  take no branch name, as gh's lock and unlock read none.
  An object is read by its web URL, which finds the pull request in the
  repository it came from, and otherwise by its number.
  A URL or object in another repository than `-Repository` throws.
- Nothing asks for confirmation unless you pass `-Confirm`:
  closing, merging, and the other changes act at once,
  so try one with `-WhatIf` first.
- `-Repository` takes OWNER/REPO, HOST/OWNER/REPO, a URL,
  or a repository object such as a listing returns.
  Left out, it means the current directory's repository;
  given as `$null`, it throws rather than fall back to that.
- A pull request left out means the current branch's.
  gh needs the pull request named along with `-Repository`,
  so with it the call throws before gh runs -
  except an edit by `Set-GitHubPullRequest`, which gh still runs.
  A pull request given as `$null` throws too, rather than meaning the
  current branch's.
- `Merge-GitHubPullRequest` needs `-Strategy`, as gh cannot ask which way to
  merge here (a merge queue sets it itself).
- `New-GitHubPullRequest` needs a title and a body, or one of the `-Fill`
  options, and has no template option: gh applies a template only along with
  its own prompts.
- `Set-GitHubPullRequest` must be told what to change.
- `Switch-GitHubPullRequest -Force` resets an existing local branch of that
  name, discarding uncommitted changes to tracked files.
- A blank value throws rather than being dropped:
  a title, base, head, milestone, comment, subject, author email, worktree,
  or head commit,
  a filter given to `Get-GitHubPullRequest -List`,
  and a name in a list of labels, assignees, reviewers, or projects.
- `Get-GitHubPullRequestCheck` returns nothing for a pull request that has no
  checks, and throws for one it cannot read.
  `-Wait` reads the checks again until none is pending,
  counting no checks reported yet as pending,
  and throws a `TimeoutException` naming what is still pending
  when time runs out.
  A pull request that never reports checks (no CI, or `-Required` with none
  required) therefore waits until `-TimeoutSeconds` and then throws:
  bound it with `-TimeoutSeconds`, or read without `-Wait`.
  Failed reads follow the polling policy TaffarelJr.GitHub.Core shares with
  every waiter;
  `-PollSeconds` and `-TimeoutSeconds` set the interval and the limit,
  and the command's help gives their defaults.
- `Get-GitHubPullRequestDiff` returns lines for reading: carriage returns at
  line ends and bytes that are not UTF-8 are not kept.
- Bodies, comments, and reviews reach gh through a temporary file, exactly
  as given. A label, assignee, reviewer, or project name with a comma in it
  is quoted, so gh keeps it whole.

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
as in `RuntimeException,Invoke-GitHubCommand,Merge-GitHubPullRequest`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name as one here.
The last one imported wins,
so call it module-qualified,
as in `TaffarelJr.GitHub.PullRequests\Get-GitHubPullRequest`,
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
