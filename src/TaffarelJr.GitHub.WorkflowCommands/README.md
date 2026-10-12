# TaffarelJr.GitHub.WorkflowCommands

The GitHub Actions runner protocol: log annotations, masking, step
outputs, environment variables, PATH, job summaries, and action state.
No `gh` CLI or API calls - this talks to the runner itself, so it works
in any Actions job regardless of what else is installed.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.WorkflowCommands
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.WorkflowCommands

Set-GitHubActionsOutput -Name 'version' -Value '1.2.3'
Write-GitHubActionsWarning -Message 'Falling back to the cached value' -File 'build.ps1' -Line 42
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
