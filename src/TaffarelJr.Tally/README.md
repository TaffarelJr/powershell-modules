# TaffarelJr.Tally

A generic named-counter utility for PowerShell scripts:
add to a counter by name, read it back, clear it,
and render every counter as one joined string for a log line or job summary.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.Tally
```

## Usage

```powershell
Import-Module TaffarelJr.Tally

Add-Tally -Name 'passed'
Add-Tally -Name 'failed' -Amount 2
Format-Tally
# 1 passed - 2 failed
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
