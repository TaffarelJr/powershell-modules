# TaffarelJr.GitHub.Search

Searches GitHub through the GitHub CLI (gh):
code, commits, issues, pull requests, and repositories.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Search
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh: `-SearchType` needs 2.98.
An older gh fails on it with its own message.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Search

Find-GitHubRepository -Owner @('TaffarelJr') -Language PowerShell

Find-GitHubIssue -Query 'crash', '-label:wontfix' -Repository 'TaffarelJr/powershell-modules'
```

## Good to know

- `-Query` takes keywords, each one a value of its own.
  A value with a space in it is searched as an exact phrase,
  so `'react lint'` is one phrase where `'react', 'lint'` is two keywords.
  A qualifier is a value of its own too, and a leading dash excludes it
  (`-label:wontfix`).
- Give a query, a filter, or both.
  With neither, or with a filter that is passed but empty or blank,
  the search would widen to all of GitHub, so it throws instead.
  Options that only shape the results or pick a state
  do not count as a filter:
  `-Limit`, `-Sort`, `-Order`, `-Match`, `-SearchType`, `-State`,
  `-Checks`, `-Review`,
  `-Visibility`, `-IncludeForks`, `-IncludePullRequests`,
  and every switch, such as `-Merged` or `-NoLabel`.
- `-Repository` and `-Owner` take several values, any of which matches.
  A repository is OWNER/REPO, a URL, HOST/OWNER/REPO,
  or a repository object, such as a search result's `Repository`.
  gh searches its default host -
  the one `GH_HOST` names, else the one host gh is logged in to,
  else github.com.
  This module compares a named host with `GH_HOST` when it is set
  and with github.com when it is not, and another host throws,
  so someone logged in only to an Enterprise host sets `GH_HOST`.
- A list value holding a comma throws, as gh would split it in two.
  Give each value on its own,
  and put a qualifier whose one value holds a comma in `-Query`, quoted:
  `'label:"a,b"'`.
- `-Archived:$false` means only non-archived;
  leave it off for both.
  `-Draft`, `-Merged`, `-Locked` and `-Merge` work the same way.
- `-NoLabel`, `-NoMilestone`, `-NoAssignee`, `-NoProject`
  and `-IncludePullRequests` have no false form:
  gh ignores one set to false, so `:$false` throws.
- A date filter takes a date or text such as `'>2026-01-01'`.
  A `[datetime]` or `[datetimeoffset]` is sent as the day it shows,
  and one with a time of day throws,
  as GitHub would match it to the exact second;
  for a moment, give text such as `'>=2026-10-11T09:33:17Z'`.
- Each function returns a fixed set of fields; there is no `-Property`.
- `-Limit` goes up to 1000,
  the most results GitHub returns for any search.

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
as in `RuntimeException,Invoke-GitHubCommand,Find-GitHubIssue`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified
(`TaffarelJr.GitHub.Search\Find-GitHubIssue`),
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
