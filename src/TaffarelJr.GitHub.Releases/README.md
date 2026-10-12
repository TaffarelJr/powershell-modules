# TaffarelJr.GitHub.Releases

Wraps the gh CLI for releases and their assets: create, edit, publish, upload,`r`nand download.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Releases
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Releases

New-GitHubRelease -Tag 'v1.2.0' -Draft -GenerateNotes -Asset './dist/*.nupkg'
Set-GitHubRelease -Tag 'v1.2.0' -Draft:$false
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules