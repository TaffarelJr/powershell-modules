# TaffarelJr.GitHub.PullRequests

Wraps the gh CLI for pull requests: create, review, merge, comment, and manage`r`ntheir lifecycle.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.PullRequests
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.PullRequests

$open = Get-GitHubPullRequest -List -Head 'template-sync' -Repository 'owner/repo'
if ($open.Count -eq 0) {
    New-GitHubPullRequest -Title 'Sync template' -Body $notes `
        -Base 'main' -Head 'template-sync' -Repository 'owner/repo'
}
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules