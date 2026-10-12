# TaffarelJr.GitHub.Search

Wraps the gh CLI to search GitHub: code, commits, issues, pull requests, and`r`nrepositories.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Search
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Search

Find-GitHubRepository -Owner @('TaffarelJr') -Language PowerShell
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules