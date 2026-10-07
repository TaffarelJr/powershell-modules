# TaffarelJr.Git

Wraps the git CLI for everyday scripting: repository state, branches,
remotes, staging and committing, push/pull, history and comparisons,
tags, merging, conflict resolution, rebasing, stashing, and config.
Every call goes through one process-invocation core - never git
directly, and never an interactive editor.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.Git
```

## Usage

```powershell
Import-Module TaffarelJr.Git

# stage, commit, and push only if something actually changed
if (Test-GitChange -Staged) {
    New-GitCommit -Message 'Update generated files'
}

# capture before piping - Get-GitStatus's own result must be a variable
# first, or a direct pipe sees it as one record instead of one per path
$changed = Get-GitStatus
$changed | Where-Object Status -like 'M*' | Add-GitChange
if (Test-GitChange -Staged) {
    New-GitCommit -Message 'chore: sync generated files'
    Push-GitCommit -SetUpstream
}

# branch housekeeping
$current = Get-GitBranch
$branches = Get-GitBranch -List
$stale = $branches | Where-Object { $_ -ne $current }
$stale | Remove-GitBranch
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
