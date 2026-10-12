# TaffarelJr.GitHub.Account

Wraps gh's own authentication, account switching, credential-helper setup,
organization membership, and local CLI configuration.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.GitHub.Account
```

## Usage

```powershell
Import-Module TaffarelJr.GitHub.Account

if (-not (Get-GitHubAuthStatus -Active)) {
    Connect-GitHubAccount -Token $env:GH_TOKEN
}
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules