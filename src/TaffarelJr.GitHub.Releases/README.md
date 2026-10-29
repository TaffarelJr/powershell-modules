# TaffarelJr.GitHub.Releases

Manages GitHub releases through the GitHub CLI (gh):
create, edit, publish, and delete releases,
and upload, download, and remove their assets.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Releases
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh:
`Get-GitHubRelease`'s default fields need 2.76,
those of `Get-GitHubRelease -List` 2.83,
and `New-GitHubRelease -FailOnNoCommits` 2.68.
An older gh fails on them with its own message;
for `Get-GitHubRelease`, name the fields it has with `-Property`.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Releases

New-GitHubRelease -Tag 'v1.2.0' -Draft -GenerateNotes -Asset './dist/*.nupkg'
Set-GitHubRelease -Tag 'v1.2.0' -Draft:$false

Get-GitHubRelease -List -Limit 1000 -Repository 'o/r' | Where-Object IsDraft | Set-GitHubRelease -Draft:$false
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- A release from `Get-GitHubRelease` carries the repository it was read from,
  and a release piped on, or given as `-Tag`, is acted on there,
  not in the current directory's repository.
  It is written `OWNER/REPO` (`HOST/OWNER/REPO` off github.com),
  however the repository was named,
  so `Where-Object Repository -EQ 'OWNER/REPO'` finds every release of it.
  A listing of the current directory's repository carries `$null`.
- An empty `-Tag` or `$null` throws; only leaving `-Tag` out means the latest
  release. Likewise `-Repository $null` throws;
  leave it out for the current directory's repository.
- `-Notes` and `-NotesFile` cannot be given together -
  gh would use the file and drop the text without saying so.
  `-Notes` reaches gh exactly as given, and `-Notes ''` clears the notes.
- gh expands wildcards in an `-Asset` or `-Path` (`./dist/*.nupkg`),
  and reads `#Label` on the end as the asset's display label -
  such a path is taken literally, never as a pattern.
  gh cuts the path at its first `#`, so a `#` anywhere in it,
  a folder name included, breaks it.
- `-LiteralPath` (`-LiteralAsset` on `New-GitHubRelease`) names files exactly,
  as files piped in from `Get-ChildItem` are:
  no wildcards, and a `#` in the path is avoided where it can be.
- `-Pattern` on `Save-GitHubReleaseAsset` matches case-sensitively,
  even on Windows.
- `Remove-GitHubRelease` and `Remove-GitHubReleaseAsset` delete without
  asking: nothing asks for confirmation unless you pass `-Confirm`.

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
`Add-GitHubReleaseAsset` differs:
it gathers the files piped to it and uploads them in one `gh` call,
so a failing record uploads nothing,
and the files must all be for one release.
A piped value that fails to bind, such as `$null`, is the exception:
that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Invoke-GitHubCommand,Get-GitHubRelease`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name, and the last one
imported wins; call it module-qualified
(`TaffarelJr.GitHub.Releases\Get-GitHubRelease`) or import this module with
`-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
