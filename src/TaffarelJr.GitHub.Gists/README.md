# TaffarelJr.GitHub.Gists

Manages GitHub gists through the GitHub CLI (gh):
create, read, edit, clone, and delete gists, and rename their files.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Gists
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh: `Remove-GitHubGist` needs 2.66.
An older gh fails on it with its own message.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Gists

New-GitHubGist -Path @('notes.md') -Description 'Scratch notes' -Public

$gist = Get-GitHubGist -Id 'https://gist.github.com/me/0123456789abcdef0123456789abcdef'
$gist.Files['hello_world.py'].Content
$gist.Files.PSBase.Values | ForEach-Object Filename
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Every function that acts on a gist takes it by its id,
  by the https and SSH URLs GitHub gives for it
  (page, raw, clone, embed, or API URL, on github.com or an Enterprise server),
  or as an object from `Get-GitHubGist`, piped or not.
  Only the id is kept: gh asks its own default host for it.
- `Get-GitHubGist` returns `Files` as a dictionary keyed by each file's
  real name, case and all - `hello_world.py` stays `hello_world.py` -
  while its other fields are PascalCase.
  Read its names and files through `PSBase`
  (`$gist.Files.PSBase.Keys`, `$gist.Files.PSBase.Values`),
  as a file named `Keys`, `Values`, or `Count` would stand in for the member.
- A file's content is always its text, up to the first megabyte:
  a larger file has `Truncated` set,
  and its `RawUrl` has all of it up to ten megabytes.
  GitHub lists at most 300 files of a gist;
  past either limit, clone the gist with `Copy-GitHubGist`.
- `Get-GitHubGist -List` lists every gist, page after page.
- `New-GitHubGist` must be told its source: files with `-Path`,
  or text with `-Content` and `-FileName`. It sends each file's content
  exactly, through GitHub's API, and refuses a file that is empty, blank,
  binary, or not UTF-8. The one change it makes is to drop a UTF-8
  byte-order mark at the start of a file, so a script that Windows
  PowerShell saved with one still starts with its `#!` line.
- `Set-GitHubGist` makes one change per call: the description
  (`-Description ''` clears it), or one file added, removed, or replaced,
  from a local file held to the same rules.
  Adding a file under a name the gist already has is refused.
- `Copy-GitHubGist` returns the folder it cloned into.
- `Remove-GitHubGist` deletes without asking:
  nothing asks for confirmation unless you pass `-Confirm`.

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
as in `RuntimeException,New-GitHubGist` for a refused argument
and `InvalidOperationException,Get-GitHubGist` for a failed API call.
Both have the `InvalidOperation` category, as do most failures,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name, and the last one
imported wins; call it module-qualified
(`TaffarelJr.GitHub.Gists\Get-GitHubGist`) or import this module with
`-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
