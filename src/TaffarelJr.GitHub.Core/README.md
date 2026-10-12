# TaffarelJr.GitHub.Core

Shared plumbing every other `TaffarelJr.GitHub.*` module builds on.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Core
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Core

# the escape hatch every TaffarelJr.GitHub.* module is built on
$repo = Invoke-GitHubApi 'repos/{owner}/{repo}'
$repo.default_branch
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules