# TaffarelJr.TestKit

A minimal, homegrown test-writing kit:
`Assert-That`, `Assert-Equal`, `Assert-Throws`, a per-file pass/fail tally,
and `Get-HostOutput` for capturing what a script block printed via `Write-Host`.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.TestKit
```

## Usage

```powershell
Import-Module TaffarelJr.TestKit

Assert-Equal -Expected 4 -Actual (2 + 2) -Message '2 + 2 is 4'
exit (Complete-TestRun)
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
