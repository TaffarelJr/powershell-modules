# TaffarelJr.GitHub.Repositories

Creates, configures, and removes GitHub repositories
through the GitHub CLI (gh), and manages what belongs to them:
labels, secrets, variables, deploy keys, and rulesets.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Repositories
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh:
`Get-GitHubVariable` 2.53,
`Set-GitHubRepository -Visibility` 2.61,
the security switches of `Set-GitHubRepository` 2.65,
`-NoReposSelected` 2.75,
a remote name for `Set-GitHubDefaultRepository` 2.85,
`-SquashMergeCommitMessage` 2.88,
the `agents` application of the secret functions 2.93,
and `Set-GitHubDefaultRepository -Unset` 2.102.
An older gh fails on them with its own message.
`New-GitHubFork` returns the new fork's URL only from gh 2.65;
an older gh prints none without a terminal, so nothing comes back.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Repositories

New-GitHubRepository -Name 'owner/repo' -Visibility private -AddReadme
Get-GitHubRepository -Repository 'owner/repo'

$key = Read-Host 'NuGet API key' -AsSecureString
Set-GitHubSecret -Name 'NUGET_API_KEY' -SecureValue $key -Repository 'owner/repo'
Get-GitHubLabel -Repository 'owner/repo' -Search 'stale' |
    Where-Object Name -eq 'stale' |
    Remove-GitHubLabel -WhatIf
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Anything piped in from a `Get-` function is acted on where it came from:
  a repository by its `Url`, a label by the repository its `Url` names,
  a ruleset by its `Source` and the host it was listed from, and a secret,
  variable, or deploy key by the `Repository`, `Environment`,
  `Organization`, `User`, and `Application` it was listed with.
- Nothing asks for confirmation unless you pass `-Confirm`:
  the removers delete at once, so try one with `-WhatIf` first.
- A label, and a secret, variable, or deploy key being removed, refuse a
  scope given as a parameter that names another place than the piped
  object's - another repository or host, another environment, an
  organization, or (for a secret) another application - and a
  `-Repository` beside an object listed from the current directory's
  repository. A piped object listed without a host lives on gh's default
  host: the one `GH_HOST` names, else github.com.
  `Set-GitHubSecret` and `Set-GitHubVariable` let a scope given as a
  parameter win, so a listed name can be applied elsewhere on purpose;
  a `-Repository` naming the piped object's own repository keeps its
  environment and its host.
  A label object with no `Url` - an issue's or a pull request's label -
  does not say its repository, so it needs `-Repository`.
- A repository parameter given as `$null` - a filter that matched nothing -
  throws; only leaving it out means the current directory's repository.
  `Rename-GitHubRepository`, and `Set-GitHubRepository` with `-Archived` or
  `-Visibility`, need the repository named.
- `Set-GitHubSecret` takes its value as a SecureString with `-SecureValue`
  or as text with `-Value`, which lands in the command history;
  either travels on standard input, and gh drops any line breaks from the end.
  An empty value is refused.
- `-EnvFile` files are parsed by gh: `$NAME` in an unquoted or double-quoted
  value is replaced from gh's environment, and an unquoted value ends at
  ` #`. Single-quote any value holding `$`, `#`, or `\`, and save the file
  as UTF-8 without a byte-order mark: a byte-order mark or a UTF-16 file is
  refused. `-EnvFile` takes no piped input.
- `Set-GitHubRepository` and `Set-GitHubLabel` throw when told nothing to
  change. gh cannot clear a label's description, so an empty one is refused.
- `-EnvFile` (secrets, variables), `Add-GitHubDeployKey`'s `-KeyFile`, and
  `New-GitHubRepository`'s `-Source` take a relative path from the current
  location.
- `Get-GitHubRuleset` and `Get-GitHubRulesetCheck` read GitHub's API, and
  take a GitHub Enterprise host from the repository or `-Hostname` -
  a bare host name, with no port.
- `Get-GitHubRepository` returns a fixed set of fields.
- `Get-GitHubDefaultRepository` returns nothing when none is set,
  and throws outside a git repository.
- Every message, `-WhatIf` line, and listed `Repository` property hides the
  credential a URL carries, as in `https://x-access-token:<token>@github.com/o/r`,
  through TaffarelJr.ProcessInvocation's `Hide-UrlCredential` -
  in a repository, a path, an organization, or a name.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters,
its examples, and what it takes from the pipeline and returns.

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
as in `RuntimeException,Invoke-GitHubCommand,Get-GitHubLabel`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line
(for example `-Value 'literal'`) is shown there:
give a secret by variable or as a SecureString.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call a command module-qualified,
as in `TaffarelJr.GitHub.Repositories\Get-GitHubLabel`,
or import the module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
