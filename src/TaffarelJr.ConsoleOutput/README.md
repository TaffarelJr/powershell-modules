# TaffarelJr.ConsoleOutput

Indent-aware console status output for PowerShell scripts:
success/skip/warn/failure lines, `Doing`/`Done` progress,
numbered step banners, and word-wrapped, box-drawn headers and banners.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ConsoleOutput
```

## Usage

```powershell
Import-Module TaffarelJr.ConsoleOutput

Write-Step 'Build'
Write-Doing 'Compiling'
Write-Done
Write-Success 'Build complete'
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
