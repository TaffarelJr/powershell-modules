# TaffarelJr.FileText

Reads and writes text files
without disturbing their existing encoding or line ending,
and replaces a placeholder token across a whole directory tree -
file content, file names, and directory names.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.FileText
```

## Usage

```powershell
Import-Module TaffarelJr.FileText

$file = Read-TextFile -Path .\README.md
Write-TextFile -Path .\README.md -Content ($file.Content -replace 'old', 'new')

Rename-Token -Path . -From 'Placeholder' -To 'MyProject'
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
