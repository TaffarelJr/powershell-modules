# TaffarelJr.GitHub.Issues

Works with GitHub issues through the GitHub CLI (gh):
create, edit, comment on, move, and close them, and read them back.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Issues
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.94 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
That version is what the default fields of `Get-GitHubIssue` and
`Get-GitHubIssueStatus` and the issue type, parent, sub-issue, and blocking
options ask for; an older gh fails on them with its own message.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Issues

New-GitHubIssue -Title 'Flaky test' -Body 'Fails one run in ten.' -Label @('bug') -Repository 'owner/repo'

# preview the close first, then run it without -WhatIf
Get-GitHubIssue -List -State open -Label 'stale' -Repository 'owner/repo' |
    Close-GitHubIssue -Reason 'not planned' -WhatIf
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Every function that acts on an issue takes its number, its URL,
  or an issue object, so a listing or a search result pipes straight in.
  An object is read by its URL, which finds the issue in the repository it
  came from; every issue this module returns carries one,
  whatever `-Property` names.
  A URL or object in another repository than `-Repository` throws.
- `-Repository` takes OWNER/REPO, HOST/OWNER/REPO, a URL,
  or a repository object such as a listing returns.
  Left out, it means the current directory's repository;
  given as `$null`, it throws rather than fall back to that.
- A pull request's URL, or an object that says it is a pull request,
  is refused: gh's issue commands would act on the pull request.
  A bare number cannot be told apart,
  so a number that is a pull request's reaches gh, which acts on it.
- `Get-GitHubIssue` and `Get-GitHubIssueStatus` leave out `comments`,
  which brings every thread, and `projectItems`, which needs a token with the
  `read:project` scope; name them with `-Property` to get them.
- Bodies and comments reach gh through a temporary file,
  so they arrive exactly as given.
  The comment `Close-GitHubIssue` and `Open-GitHubIssue` leave
  goes on gh's command line instead, which on Windows holds at most
  32,767 characters.
- `New-GitHubIssue` needs a title and a body, as gh does when it cannot
  prompt, and has no template option for the same reason.
- `Set-GitHubIssue` must be told what to change.
- Nothing asks for confirmation unless you pass `-Confirm`:
  `Remove-GitHubIssue` deletes at once, so try it with `-WhatIf` first.
- A blank value throws rather than being dropped:
  a title, milestone, type, comment, or destination repository,
  a filter given to `Get-GitHubIssue -List`,
  and a name in a list of labels, assignees, or projects.

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
as in `RuntimeException,Invoke-GitHubCommand,Close-GitHubIssue`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name, and the last one
imported wins; call it module-qualified
(`TaffarelJr.GitHub.Issues\Get-GitHubIssue`) or import this module with
`-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
