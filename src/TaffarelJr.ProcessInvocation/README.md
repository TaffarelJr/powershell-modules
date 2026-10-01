# TaffarelJr.ProcessInvocation

Runs an external command with its output captured and consistently decoded,
throwing a clear, detailed error when it fails -
or, for a tolerated failure, reporting what happened instead of throwing.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ProcessInvocation
```

## Usage

```powershell
Import-Module TaffarelJr.ProcessInvocation

Invoke-NativeCommand -Activity 'Compiling' -Command 'some-tool' `
    -Arguments @('build', $Path)

$read = Invoke-NativeRead -Command 'some-tool' -Arguments @('check', $Path)
if ($read.Ok) { ... }
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
