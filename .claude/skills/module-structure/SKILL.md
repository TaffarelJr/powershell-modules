---
name: module-structure
description: >-
  Layout, manifest, root .psm1, README, CHANGELOG and checklist for a module in
  this repo. Use when adding, restructuring or reviewing a module, its manifest
  or its README, or preparing it for publishing.
when_to_use: >-
  Trigger phrases: add a module, module manifest, psd1, module README,
  CHANGELOG, RequiredModules, prepare for publishing.
---

# Module structure

This repo hosts independently versioned PowerShell modules, each meant for the
PowerShell Gallery. A module owns its folder. One that builds on another lists
it in `RequiredModules` at the version it was built against, and never
dot-sources across folders. Design every module from the wrapped tool's own
model for any consumer, not for the repo that happens to call it first.

Before adding a module or a large helper, look for an existing public one
(PowerShell Gallery, GitHub, PowerShell 7.4 built-ins) with real fetches, never
from memory, and record the verdict (replace, adopt inside, or keep our own)
and why in the README or the pull request.

## Layout

```text
README.md  LICENSE  PSScriptAnalyzerSettings.psd1       (analyzer rules for src)
src/<ModuleName>/
  <ModuleName>.psd1  <ModuleName>.psm1  README.md  CHANGELOG.md
  Public/Verb-Noun.ps1              (one exported function per file)
  Private/Verb-Noun.ps1             (one helper per file)
  Private/ConvertTo-CommandError.ps1   (every module; the same text)
  Scripts/                          (only if the module starts child pwsh -File)
test/
  <ModuleName>/                     (mirrors src; see module-tests)
  GitHubTestHelper.ps1  Invoke-Tests.ps1  PSScriptAnalyzerSettings.psd1
  PublicSurfaceTestHelper.ps1  PublicSurfaceTestHelper.Tests.ps1
```

- The filename is the function name. The `.psm1` dot-sources `Private/` then
  `Public/` and exports the public functions by name: never a wildcard, in the
  manifest or in `Export-ModuleMember`. `Scripts/` files are never
  dot-sourced; their tests mirror them.
- Function verbs are approved (`Get-Verb`), with no decorative noun prefix. A
  generic noun can collide with another module's command: the README's
  `Name collisions` section says how to call around it.
- A module is `TaffarelJr.<Name>`: the Gallery is a flat namespace with no
  reserved prefixes, and the prefix is the only protection against a
  collision. Confirm the exact name is free on the Gallery before the first
  publish.
- Two analyzer settings files: `PSScriptAnalyzerSettings.psd1` at the root
  applies to `src`, and `test/PSScriptAnalyzerSettings.psd1` to the tests. Each
  switches a rule off only when most of its files break it, and says why; a
  function that has to break a rule suppresses it where it breaks it, with a
  true one-line `Justification`.

## The root .psm1

Copy `src/TaffarelJr.Tally/TaffarelJr.Tally.psm1` (no dependencies) or
`src/TaffarelJr.Git/TaffarelJr.Git.psm1` (with them), and list the exports.

- `#Requires -Version 7.4`, then `Set-StrictMode -Version Latest` and
  `$ErrorActionPreference = 'Stop'`, then the dot-sourcing loop and a literal,
  sorted `Export-ModuleMember -Function` list. A `using namespace` line goes
  right after `#Requires`; module state (`src/TaffarelJr.ConsoleOutput`) goes
  after the preference lines and before the loop.
- With dependencies, a loop before the dot-sourcing imports each required module
  into the module's own scope: a call into another module otherwise resolves
  through the global scope, where a later same-named command wins. It is
  `Import-Module -ModuleInfo $loaded`: never `-Global`, never by name or path,
  and the names are exactly the manifest's `RequiredModules`.
- A module-wide default that callers may also read is
  `New-Variable -Option ReadOnly -Scope Script` in the root `.psm1`, exported
  with `Export-ModuleMember -Variable` and listed in the manifest's
  `VariablesToExport`. Not `Option Constant`: a constant can never be removed,
  so a second `Import-Module -Force` fails. A `ReadOnly` variable needs
  `Remove-Module -Force`. Functions read a private copy
  (`$script:IndentWidth = $DefaultIndentWidth`); the exported one only
  informs.

## The manifest

Copy `src/TaffarelJr.Tally/TaffarelJr.Tally.psd1` and keep its key order.

- `ModuleVersion = '0.1.0'` (`repo-workflow`), a new GUID,
  `PowerShellVersion = '7.4'` and `CompatiblePSEditions = @('Core')`.
- `Author` and `CompanyName` are the holder named in `LICENSE`, and `Copyright`
  is `(c) <year> <holder>.` from `LICENSE`'s line (the public-surface test
  checks the exact form).
- Literal export lists, never `'*'`. `Description` is one string: a `+`
  concatenation does not load in a data file.
- `RequiredModules` names each dependency with the `ModuleVersion` it was built
  against, which is a minimum, not a pin (`publishing-modules`).
- Tags include `PSEdition_Core`. Add a platform tag (`Windows`, `Linux`,
  `MacOS`) only once the module's tests passed there.
- `ProjectUri`, `LicenseUri` and `ReleaseNotes` (the module's `CHANGELOG.md` URL)
  follow the existing manifests exactly.

## README, CHANGELOG, help

- `README.md` and `CHANGELOG.md` sit next to the `.psd1`: publishing packages
  only that folder, so both travel with the module. The Gallery does not render
  the README, so the manifest `Description` must stand alone
  (`publishing-modules`).
  The README is install plus a minimal usage example, not a command reference
  (comment-based help goes stale less). Prose is timeless (no counts, history
  or speculation), en-US, wrapped at phrase boundaries.
- Sections in order: title; one paragraph;
  `Part of the [powershell-modules] collection.`; `## Install`
  (`Install-PSResource -Name TaffarelJr.<Name>`, then "Requires PowerShell 7.4
  or later", and for a module that wraps gh: the GitHub CLI (gh) at its
  minimum version, from https://cli.github.com, signed in with `gh auth login`
  or given `GH_TOKEN`); `## Usage`; optional `## Good to know` (a module whose
  `Remove-*` commands delete without asking says so here); `## Errors`;
  `## Name collisions`; the link footnote. The public-surface test checks the
  `Errors` and `Name collisions` sections.
- `## Errors`: copy the section from `src/TaffarelJr.Tally/README.md` and keep
  only the variants that are true for the module (probe each claim). The ones
  that exist: the pipeline variant (a failing record stops the pipeline; name
  any function that gathers its input first, and the piped value that fails to
  bind, which is PowerShell's own error), the non-throwing variant (a command
  that returns `Ok = $false` or throws once after going past failing items), and
  the secrets variant (the default error view quotes the calling line, so give
  a secret by variable).
- Every public function's every parameter has a `.PARAMETER`, however obvious:
  `Get-Help -Full` is what a Gallery visitor sees.
- CHANGELOG: copy `src/TaffarelJr.Tally/CHANGELOG.md`; it follows Keep a
  Changelog (`publishing-modules`). Until the first publish everything sits
  under `## [Unreleased]` as `### Added` bullets, edited as the module changes.
- A new module gets a row in the root `README.md` table: the short name as a
  link, the description, `-` for the version until published, in alphabetical
  order. No test checks it.

## Versioning

Every module stays `0.1.0` until real Gallery publishing starts: no version
bumps (`repo-workflow` says how fixes are committed). After publishing, a tag is
`<ModuleName>/vX.Y.Z` (a bare `vX.Y.Z` is ambiguous in a repo of many modules);
the manifest's `ModuleVersion` is what is published. What a module needs before
its first publish is in `publishing-modules`.

## Adding a module

1. Search for an existing component (above); decide and record.
2. Copy the `.psm1` and manifest shapes, write the README and CHANGELOG, and
   copy `src/TaffarelJr.GitHub.Core/Private/ConvertTo-CommandError.ps1` byte for
   byte.
3. Write each function from the skeleton in `public-function-contract`, with
   its tests and the module-wide test files from `module-tests`.
4. Add `PublicSurface.Tests.ps1` and make it pass, and add the root README row.
5. Run `Invoke-Tests.ps1 -Module <Name>` and the analyzer on every file, then
   commit as `repo-workflow` says.
