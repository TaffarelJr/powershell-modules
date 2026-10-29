# TaffarelJr.RequiredModules

Declares the PowerShell Gallery modules a script needs
in a small `.psd1` manifest,
then checks them, installs what is missing without a prompt,
and imports them -
on a developer's machine and in CI alike,
failing clearly when an install does not work
instead of leaving someone to guess what's missing.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.RequiredModules
```

Requires PowerShell 7.4 or later.

## Usage

The manifest is this module's own format:
a hashtable keyed by module name,
each value a hashtable with, optionally,
`MinimumVersion` and `DocumentationUrl`.
An entry with no `MinimumVersion` (an empty `@{}`) means any version will do.
`RequiredModules.psd1`:

```powershell
@{
    Pester = @{
        MinimumVersion   = '5.0.0'
        DocumentationUrl = 'https://pester.dev'
    }
}
```

`Assert-RequiredModule` installs every module that is missing or too old,
then checks that each one is now found at its minimum version;
it does not import them. `Import-RequiredModule` does that:

```powershell
Import-Module TaffarelJr.RequiredModules

Assert-RequiredModule -Path 'RequiredModules.psd1'
Get-RequiredModule -Path 'RequiredModules.psd1' | Import-RequiredModule
```

`Update-RequiredModule` brings the modules to the newest version
the Gallery has, whether or not they already meet their minimum,
and installs any that is missing:

```powershell
Get-RequiredModule -Path 'RequiredModules.psd1' | Update-RequiredModule
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

A hashtable built in code works the same way, without a separate file -
`-Data` also accepts pipeline input,
and so does `-Path`, from a piped file:

```powershell
Assert-RequiredModule -Data @{
    Pester = @{ MinimumVersion = '5.0.0' }
}

@{ Pester = @{ MinimumVersion = '5.0.0' } } | Assert-RequiredModule

Get-ChildItem -Recurse -Filter RequiredModules.psd1 | Assert-RequiredModule
```

## Good to know

- A manifest is checked entry by entry, and a mistake is named:
  a module name that is not a plain package name (a wildcard, a path,
  a leading `-`), a `MinimumVersion` that is not a quoted version such as
  `'5.0.0'` (an unquoted `5.10` is the number 5.1, so every number is
  refused; a prerelease label is not supported),
  or a key other than `MinimumVersion` and `DocumentationUrl`.
  A `RequiredModules.psd1` written for PSDepend
  has a different shape and is refused the same way.
  Modules given to `Test-RequiredModule`, `Install-RequiredModule`,
  `Import-RequiredModule`, and `Update-RequiredModule` as objects
  are checked by the same rules, so a name that is a pattern is refused
  rather than matched against every module.
- Versions compare as .NET `[Version]` values,
  the way `Import-Module -MinimumVersion` compares them,
  so a missing part is lower than a zero:
  a module whose own version is `5.0` does not meet a minimum of `5.0.0`.
  Write the minimum with as many parts as the module's version has.
- Modules are handled in name order, whatever order the manifest keeps them in.
  A module named in more than one piped manifest
  is checked once, at the highest minimum.
- A module already loaded counts as installed,
  even one imported by its path rather than found on `PSModulePath`,
  and `Import-RequiredModule` leaves a module loaded at a good enough version
  as it is, rather than reloading it.
  That holds in this session only:
  a new process finds only what is on `PSModulePath`.
- `Assert-RequiredModule` asks nobody anything by default.
  An install that fails, or that still leaves the module not found
  or too old, stops it at once with the reason,
  the install command to run by hand, and the documentation link.
- `-Confirm` makes it ask before each install,
  as does a `$ConfirmPreference` of `Medium` or lower;
  a module said no to is skipped,
  and every one skipped is named in a single failure at the end.
  Where no one can answer (`pwsh -NonInteractive`), the question fails.
  `-Confirm:$false` is the same as leaving it out.
- With `-WhatIf`, `Assert-RequiredModule` names each module it would install
  and does not fail for them.
- `Install-RequiredModule` installs and returns, without checking the result;
  `Assert-RequiredModule` is the one that verifies and fails.
  It skips a module that is already satisfied,
  so running it again downloads nothing new.
  Installs go to the current user with `Install-Module -Force`,
  which suppresses the host's trust prompt for the repository,
  and `-SkipPublisherCheck`,
  so a module signed by a different publisher than an installed one
  (Pester 5 over the Pester 3 that ships with Windows) is not refused.
  The install command a message shows passes the same switches.
- `Update-RequiredModule` runs `Update-Module -Force` for each module that is
  installed, and installs one that is not; like an install, it asks nobody
  unless given `-Confirm`. It does not check the result.
- A module already loaded at a good enough version is found without scanning
  `PSModulePath`, which takes seconds on a machine with many modules.
- With `-Verbose`, `Install-RequiredModule` shows the `Install-Module` command
  before it runs.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Errors

A failing call is a terminating error for that call:
the function stops where it failed,
and `-ErrorAction SilentlyContinue` and `Ignore` neither skip nor hide the error.
It ends the call, not the caller's script,
unless the script sets `$ErrorActionPreference = 'Stop'`
(the `pwsh` shell of GitHub Actions already does)
or catches the error with `try` and `catch`.

A failing record in a pipeline stops the pipeline,
and the records before it were processed;
`Assert-RequiredModule` gathers its input first and acts on it at the end,
so a failing record means nothing was done.
A piped value that fails to bind, such as a string where `-Data` takes
a hashtable, is the exception:
that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Get-RequiredModule,Assert-RequiredModule`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified (`TaffarelJr.RequiredModules\<Command>`)
or import the module with `-Prefix` to keep them apart.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
