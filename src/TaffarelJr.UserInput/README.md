# TaffarelJr.UserInput

Small, composable interactive-prompting primitives for PowerShell scripts:
read a value or a secret, validate it, retry on failure, confirm yes/no,
pick from a menu, and check or persist an environment variable.
Each piece does one job - assemble them per prompt
instead of configuring one do-everything function.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.UserInput
```

## Usage

```powershell
Import-Module TaffarelJr.UserInput

# environment-first, then a validated, bounded-retry prompt
$name = Get-EnvironmentVariable -Name 'REPO_NAME'
if (-not $name) {
    $name = Invoke-InputRetry -ScriptBlock {
        Read-Input -Prompt 'Repo name' | Assert-Input -Require
    }
}

# a secret, persisted so the next run does not ask again
$token = Get-EnvironmentVariable -Name 'MY_TOKEN'
if (-not $token) {
    $token = Read-Secret -Prompt 'Token'
    if ($token) { $token | Set-EnvironmentVariable -Name 'MY_TOKEN' }
}
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
