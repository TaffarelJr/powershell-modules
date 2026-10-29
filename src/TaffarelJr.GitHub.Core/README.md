# TaffarelJr.GitHub.Core

The shared groundwork of the modules that drive the GitHub CLI (gh):
`TaffarelJr.GitHub.Account`, `.Gists`, `.Issues`, `.PullRequests`,
`.Releases`, `.Repositories`, `.Search` and `.Workflows`.
A script calls three of its commands directly:
`Invoke-GitHubApi`, for a REST or GraphQL call those modules do not cover;
`Test-GitHubApi`, to ask whether something exists;
and `ConvertFrom-GitHubJson`, to read gh's own JSON output as objects.
The rest are building blocks for the modules.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Core
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`:
`Invoke-GitHubApi -Paginate` relies on `gh api --slurp`, added in 2.48.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Core

# the raw API escape hatch, for anything without a dedicated function
$repo = Invoke-GitHubApi 'repos/cli/cli'
$repo.default_branch

# inside a git checkout, gh fills {owner} and {repo} from its remote
$here = Invoke-GitHubApi 'repos/{owner}/{repo}'
```

## Good to know

- What a function parses is gh's stdout alone, so a warning on stderr
  cannot corrupt a JSON response. Stderr still appears in a failure message,
  without the usage text gh adds after a bad flag.
- Parsed JSON keeps its types: a string stays a string even when it looks
  like a timestamp. Only a timestamp under a key ending in `At`, `_at`, or
  `Date` becomes a `[datetime]`, and gh's "never set" time (year 0001)
  becomes `$null`. Keys that a PowerShell object cannot hold - two that
  differ only in case, say - come back in a case-sensitive dictionary
  rather than being lost. List the keys and values of such a dictionary, or
  of a `-KeepKeysOf` one, with `.PSBase.Keys` and `.PSBase.Values`: a key
  named `Keys` or `Values` would answer `.Keys` or `.Values` instead.
- `Test-GitHubApi` answers `$false` only when the thing is not there: a 404
  or a 410. Every other failure - a refused or forbidden token, a rate
  limit, a server error, no network, no login, a missing `gh` - throws with
  its HTTP status and gh's reason instead of reading as "gone".
- `Invoke-GitHubApi -Field` is typed by gh, which also reads a value starting
  with `@` from a file; a string that must stay a string, or comes from
  outside, goes in `-RawField`.
- `Invoke-GitHubApi` supports `-WhatIf` and `-Confirm` for a call that can
  change something: any method but GET and HEAD, to any endpoint but
  `graphql`, whose every query is a POST. A read always runs.
- `ConvertFrom-GitHubJson` and `ConvertTo-PascalCaseObject` take pipeline
  input. They gather it and convert it at the end, so
  `gh pr list --json number | ConvertFrom-GitHubJson` parses gh's lines as
  one document.
- Every message these functions write hides the credential a URL carries,
  as in `https://x-access-token:<token>@github.com/o/r`, through
  TaffarelJr.ProcessInvocation's `Hide-UrlCredential` - in an argument, an
  endpoint, a repository, or a line gh printed - and a GitHub token that
  stands alone.
  `Invoke-GitHubCommand -Mask` hides any other value a caller names,
  through `Hide-MaskedValue`, in the activity, each argument, and each line
  gh printed, and in the verbose line.
  `Invoke-GitHubApi` names the value of every `-Header`, and of every
  `-Field` or `-RawField` whose key holds `secret`, `token`, `passw`,
  `credential`, `auth`, `api-key`, `private`, or `signature` (also nested,
  as in `config[secret]`), so those show as `***` in a message.
  Any other secret goes in `-Body`, which is sent by standard input and
  never shown.
- gh never prompts with its output captured, but a gh command that wants an
  editor still starts one. No function of these modules runs such a command;
  `Invoke-GitHubCommand -Environment @{ GH_EDITOR = '...' }` pins one for a
  caller who might.
- The checks the modules share live here, so every module refuses the same
  mistakes in the same words: `Assert-GitHubHostname` for a `-Hostname`,
  `Resolve-GitHubRepositoryArgument` for a `-Repository` given as `$null`,
  and `Assert-GitHubSameRepository` for an item from another repository
  than `-Repository` names.
- `Format-GitHubRepositoryName` names a repository for a person to read,
  such as a `-WhatIf` target: `OWNER/REPO`, or `HOST/OWNER/REPO` off
  github.com, however it was given, and never with a token or password a
  URL carried.
  Text that names no repository comes back with its credentials hidden
  rather than throwing; only `$null` is refused,
  as PowerShell refuses it for any mandatory parameter.
- Every wait that polls gh follows one policy, through `New-GitHubPoll`,
  `Assert-GitHubPollRead`, `Wait-GitHubPoll`, and `Test-GitHubPollExpired`:
  the first failed read ends the wait with its HTTP status and gh's reason,
  whatever the failure - a 403 or a rate limit included - and what is
  waited for is only the thing polled, between good reads, up to the
  timeout. No sleep runs past the wait's deadline, and every waiter's
  timeout reads the same, through `Get-GitHubTimeoutMessage`.
- `-Verbose` writes the gh command line before it runs,
  as a failure message would show it:
  with the credential a URL carries and the `-Mask` values hidden,
  and every other argument as it is.
  `Invoke-GitHubCommand` and `Invoke-GitHubApi` follow
  the caller's `-Verbose` or `$VerbosePreference`,
  also when a function of another module calls them.

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
as in `RuntimeException,Invoke-GitHubCommand,Invoke-GitHubApi`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

`Invoke-GitHubCommand -Tolerant` returns a result with `Ok = $false`
instead of throwing when gh exits non-zero,
and `Test-GitHubApi` answers `$false` for a thing that is not there.

PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line is shown there;
give a secret by variable.

## Name collisions

Another module may export a command with the same name, and the last one
imported wins. Call the command module-qualified
(`TaffarelJr.GitHub.Core\Invoke-GitHubApi`),
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
