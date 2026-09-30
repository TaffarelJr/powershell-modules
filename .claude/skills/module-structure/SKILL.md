---
name: module-structure
description: >-
  Lays out a new PowerShell module in this repo and checks an existing one
  for drift: the src/<Module> and test/<Module> folder shape, the
  TaffarelJr.<Name> naming rule, module manifest hygiene, and per-module
  versioning. Use when adding a module, restructuring one, or preparing a
  manifest for publishing.
when_to_use: >-
  Trigger phrases: add a module, new PowerShell module, structure this
  module, module manifest, prepare for publishing, is this module
  structured correctly.
allowed-tools: Read Edit Write Glob Grep Bash
---

# Module structure

This repo hosts several independently-versioned PowerShell modules, each
published on its own to the PowerShell Gallery. Every module owns its own
folder; nothing here is shared code between modules at runtime.

## Layout

```text
src/<ModuleName>/
  <ModuleName>.psd1
  <ModuleName>.psm1
  Public/
    Verb-Noun.ps1
  Private/
    Verb-Noun.ps1
test/<ModuleName>/
  Public/
    Verb-Noun.Tests.ps1
  Private/
    Verb-Noun.Tests.ps1
```

- One exported function per file under `Public/`; the filename matches the
  function name.
- Internal-only helpers live under `Private/`, under the same one-file-per-
  function rule.
- `<ModuleName>.psm1` dot-sources everything under `Public/` and `Private/`,
  then exports only the `Public/` functions by name — never a wildcard in
  the manifest or `Export-ModuleMember *`.
- `test/<ModuleName>/` mirrors `src/<ModuleName>/` exactly, the same
  convention this repo's sibling, `.actions`, already uses: a test's path
  tells you its source's path without having to search for it.

## Naming

- A module is always named `TaffarelJr.<Name>` (for example,
  `TaffarelJr.ConsoleOutput`). The Gallery is a flat, global namespace with
  no enforced ownership of a prefix — a generic module name risks colliding
  with someone else's; the prefix is the only real protection.
- Exported function verbs must be on the PowerShell-approved list
  (`Get-Verb`) — an unapproved verb loads with a console warning and fails
  `PSUseApprovedVerbs` in CI.
- Skip a decorative noun prefix; the module name already disambiguates, so
  the function noun should carry its meaning alone (`Write-Doing`, not
  `Write-TjDoing`).

## Manifest

Every `.psd1` sets, at minimum:

- `FunctionsToExport` as the literal list, never `'*'`.
- `Author` and `CompanyName` as `TaffarelJr`.
- `Description`, `ProjectUri`, `LicenseUri`, and `Tags`.
- `ReleaseNotes` pointing at `CHANGELOG.md` rather than restating it.

## Documentation

- Every module gets its own `README.md` and `CHANGELOG.md`, sitting next
  to its `.psd1` — inside `src/<ModuleName>/`, not just at the repo root.
  `Publish-Module`/`Publish-PSResource` only packages a module's own
  folder, and the Gallery only renders a `README.md` that's actually
  inside the published package; one at the repo root is invisible to it.
  The README covers install + a minimal usage example, not a full command
  reference — that duplicates comment-based help and goes stale the
  moment a function's signature changes. The changelog gets one entry per
  version, describing what that version actually shipped; unlike a
  running command list, a changelog entry is frozen to its version and
  can't go stale.
- Every public function's every parameter gets a `.PARAMETER` entry, even
  a one-liner for something that looks self-evident (`-Text`: "The line
  to print."). This is stricter than general script style, which allows
  skipping the obvious ones — `Get-Help -Full` is what a Gallery visitor
  actually sees, and a parameter with no description reads as unfinished,
  not as obvious.

## Versioning

Because several modules share one repo, a bare `vX.Y.Z` git tag is
ambiguous about which module it belongs to. Tag a release as
`<ModuleName>/vX.Y.Z`; the tag is repo history, but the manifest's own
`ModuleVersion` is what actually gets published.

## Before publishing a module for the first time

Confirm the exact name is free: `Find-Module -Name TaffarelJr.<Name>
-Repository PSGallery` should return nothing. A taken name means renaming
before it can be published at all.
