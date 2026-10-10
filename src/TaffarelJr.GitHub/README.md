# TaffarelJr.GitHub

Wraps the GitHub CLI (gh) for everyday scripting:
the REST and GraphQL API, authentication, repositories, pull requests,
releases, workflow runs and workflows, labels, secrets, and variables.
Every call goes through one process-invocation core -
never gh directly, and never a prompt -
and every JSON result comes back as objects with PascalCase properties.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub
```

Needs the [GitHub CLI] on the PATH and logged in -
or, in a GitHub Actions job, `GH_TOKEN` in the environment.
Built against gh 2.102; an older gh may lack a flag or a JSON field
a function asks for.

## Usage

```powershell
Import-Module TaffarelJr.GitHub

# find the open sync pull request, or open one
$open = Get-GitHubPullRequest -List -Head 'template-sync' -Repository 'owner/repo'
if ($open.Count -eq 0) {
    New-GitHubPullRequest -Title 'Sync template' -Body $notes `
        -Base 'main' -Head 'template-sync' -Repository 'owner/repo'
}

# draft a release with the build's artifacts, then publish it
New-GitHubRelease -Tag 'v1.2.0' -Draft -GenerateNotes -Asset './dist/*.nupkg'
Set-GitHubRelease -Tag 'v1.2.0' -Draft:$false

# anything gh has no subcommand for - field names stay GitHub's own
$repo = Invoke-GitHubApi 'repos/{owner}/{repo}'
$repo.default_branch

# a secret only ever travels on standard input, never as an argument
Set-GitHubSecret -Name 'NUGET_API_KEY' -Value $env:NUGET_API_KEY
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[GitHub CLI]: https://cli.github.com/manual
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
