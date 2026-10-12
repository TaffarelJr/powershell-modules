# TaffarelJr.GitHub.Account

Manages GitHub sign-in through the GitHub CLI (gh):
add, switch, and remove accounts, check who is signed in,
list your organizations, and read or change gh's own settings.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Account
```

Requires PowerShell 7.4 or later.
It also needs the GitHub CLI (gh), version 2.48 or later,
from [cli.github.com][gh-cli],
signed in with `gh auth login` or given `GH_TOKEN`.
Some options need a newer gh:
`Get-GitHubAuthStatus` needs 2.81, for `gh auth status --json`.
An older gh fails on it with its own message.

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Account

# is there a login that works? (Get-GitHubAuthStatus needs gh 2.81 or later)
$working = Get-GitHubAuthStatus -Active | Where-Object State -eq 'success'
if (-not $working) {
    Connect-GitHubAccount -SecureToken (Read-Host 'Token' -AsSecureString)
}
```

In a headless job, set `GH_TOKEN` in the environment instead:
gh uses it directly and needs no login at all.

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- `Get-GitHubAuthStatus` lists an account whose token gh could not use,
  with `State` of `error`, so check `State`;
  with no login at all it returns nothing rather than failing.
- `Connect-GitHubAccount` sends the token on standard input, so it never
  appears in a failure message, and takes it as a `SecureString` too;
  called with no token, it prompts with the input masked.
- `Set-GitHubConfig` refuses a setting name gh does not list, since gh itself
  would store it and only warn. The value travels as an argument, so
  `-Verbose` output and every failure message show `***` in its place
  (a very short value is not hidden).
- `Get-GitHubToken` returns a secret: keep it out of logs and the console.
  So does `Get-GitHubAuthStatus -ShowToken` - every account it returns then
  holds its token, and an unassigned call prints them all.
  `Get-GitHubConfig` refuses `oauth_token`, the stored token gh would
  otherwise hand out as a setting.
- `-Hostname` takes a bare host name such as `ghe.example.com`, not a URL,
  and `-User` a login alone.
  An empty value is refused; leave it out for the default.
- `Get-GitHubOrganization` reads every page, so its list is never cut short.

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
as in `RuntimeException,Invoke-GitHubCommand,Get-GitHubToken`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line is shown there;
give a secret by variable.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified
(`TaffarelJr.GitHub.Account\Get-GitHubToken`),
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[gh-cli]: https://cli.github.com
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
