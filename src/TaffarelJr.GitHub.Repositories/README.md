# TaffarelJr.GitHub.Repositories

Wraps the gh CLI for repository administration: create, edit, delete, fork, sync,`r`ndeploy keys, labels, rulesets, secrets, and variables.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Repositories
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Repositories

Set-GitHubSecret -Name 'NUGET_API_KEY' -Value $env:NUGET_API_KEY -Repository 'owner/repo'
Get-GitHubLabel -Repository 'owner/repo' | Where-Object Name -eq 'bug'
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules