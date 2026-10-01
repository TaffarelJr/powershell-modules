# TaffarelJr.Tally

A generic named-counter utility for PowerShell scripts:
add to a counter by name, read it back, clear it,
render every counter as one joined string for a log line or job summary,
and parse that same string back into counts.

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

Read-Tally -Text '1 passed - 2 failed'
# Name    Count
# ----    -----
# passed      1
# failed      2

# -Key isolates a set of counters under their own namespace,
# so two callers can both use a name like "passed"
# without adding to the same running count
Add-Tally -Name 'passed' -Key 'MyModule'
Format-Tally -Key 'MyModule'
# 1 passed
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
