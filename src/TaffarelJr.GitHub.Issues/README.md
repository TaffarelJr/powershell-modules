# TaffarelJr.GitHub.Issues

Wraps the gh CLI for issues: create, edit, comment, transfer, and manage their`r`nlifecycle.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Issues
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Issues

New-GitHubIssue -Title 'Flaky test' -Label @('bug') -Repository 'owner/repo'
Get-GitHubIssue -List -State open -Repository 'owner/repo'
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules