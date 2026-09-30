# TaffarelJr.RequiredModules

Declares the PowerShell Gallery modules a script needs
in a `RequiredModules.psd1` manifest,
then checks, installs, and imports them -
interactively with a prompt, or failing clearly in CI
instead of leaving someone to guess what's missing.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.RequiredModules
```

## Usage

`RequiredModules.psd1`:

```powershell
@{
    Pester = @{
        MinimumVersion   = '5.0.0'
        DocumentationUrl = 'https://pester.dev'
    }
}
```

```powershell
Import-Module TaffarelJr.RequiredModules

Assert-RequiredModule -Path 'RequiredModules.psd1'
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
