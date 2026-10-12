# TaffarelJr.GitHub.Gists

Wraps the gh CLI for gists: create, edit, rename files, clone, and delete.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Gists
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Gists

New-GitHubGist -Path @('notes.md') -Description 'Scratch notes' -Public
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules