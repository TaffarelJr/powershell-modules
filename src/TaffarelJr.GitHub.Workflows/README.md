# TaffarelJr.GitHub.Workflows

Wraps the gh CLI for GitHub Actions: dispatch and monitor workflow runs, manage`r`nworkflows, and clear Actions caches.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Workflows
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Workflows

Start-GitHubWorkflow -Workflow 'draft-release.yml' -Ref 'main'
Get-GitHubWorkflowRun -List -Workflow 'draft-release.yml' -Limit 1
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules